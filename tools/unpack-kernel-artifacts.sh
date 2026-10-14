#!/usr/bin/env bash
#
# Populate device/xiaomi/miro-kernel from the partition images produced by
# tools/extract-stock-rom.sh.
#
# Usage:
#   tools/unpack-kernel-artifacts.sh <images-dir> [kernel-tree]
#
# <images-dir> must contain boot.img, dtbo.img, vendor_boot.img, vendor_dlkm.img
# and system_dlkm.img (as dumped by payload-dumper-go).
#
# Produces this layout in <kernel-tree> (consumed by device/xiaomi/miro/BoardConfig.mk):
#
#   kernel                         raw arm64 Image from boot.img
#   dtb/NN_dtbdump_*.dtb           FDTs split from the vendor_boot dtb blob
#   dtbo.img                       prebuilt DTBO partition image
#   vendor_ramdisk/                modules.load{,.recovery}, modules.blocklist, *.ko
#   vendor_dlkm/                   modules.load, modules.blocklist, *.ko
#   system_dlkm/<version>/         modules.load, kernel/…, module metadata
#
# The vendor_ramdisk/vendor_dlkm directories are *flat* module directories: the
# build copies every file in them into /lib/modules (see find-copy-subdir-files
# in device/xiaomi/miro/BoardConfig.mk). system_dlkm keeps the stock
# lib/modules/<version>/ tree (including its kernel/ subdirectory, which
# modules.load paths are relative to).
#
# Needs: unpack_bootimg (PATH or $ANDROID_BUILD_TOP), lz4, cpio, python3,
#        and erofs-utils (fsck.erofs) or debugfs+simg2img for ext4 images.
#
set -euo pipefail

IMAGES="${1:?usage: $0 <images-dir> [kernel-tree]}"
KTREE="${2:-device/xiaomi/miro-kernel}"

[[ -d "$IMAGES" ]] || { echo "!! no such dir: $IMAGES" >&2; exit 1; }
mkdir -p "$KTREE"

die() { echo "!! $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Tool discovery
# ---------------------------------------------------------------------------
UNPACK_BOOTIMG=""
for c in \
    "${ANDROID_BUILD_TOP:-}/system/tools/mkbootimg/unpack_bootimg.py" \
    "${ANDROID_BUILD_TOP:-}/tools/mkbootimg/unpack_bootimg.py" \
    "$(command -v unpack_bootimg 2>/dev/null || true)"; do
    [[ -n "$c" && -x "$c" || -n "$c" && -f "$c" ]] && { UNPACK_BOOTIMG="$c"; break; }
done
[[ -n "$UNPACK_BOOTIMG" ]] || die "unpack_bootimg not found. Put it on PATH or set ANDROID_BUILD_TOP to a synced tree."

LZ4="$(command -v lz4 || true)"
CPIO="$(command -v cpio || true)"
PYTHON3="$(command -v python3 || true)"
FSCK_EROFS="${FSCK_EROFS:-$(command -v fsck.erofs || true)}"
SIMG2IMG="$(command -v simg2img || true)"
DEBUGFS="$(command -v debugfs || true)"

for t in LZ4 CPIO PYTHON3; do
    [[ -n "${!t}" ]] || die "$(echo "$t" | tr 'A-Z' 'a-z') not found."
done
if [[ -z "$FSCK_EROFS" && -z "$DEBUGFS" ]]; then
    die "need erofs-utils (fsck.erofs) or e2fsprogs (debugfs) to read the module images."
fi

W="$KTREE/.work"
rm -rf "$W"; mkdir -p "$W"

# ---------------------------------------------------------------------------
# 1. kernel + vendor ramdisk from boot.img / vendor_boot.img
# ---------------------------------------------------------------------------
echo ">> unpacking boot.img / vendor_boot.img"
for img in boot vendor_boot; do
    [[ -f "$IMAGES/$img.img" ]] || die "$img.img missing in $IMAGES"
    mkdir -p "$W/$img"
    "$UNPACK_BOOTIMG" --boot_img "$IMAGES/$img.img" --out "$W/$img" --format=mkbootimg >/dev/null
done

KERNEL_SRC=""
for c in "$W/boot/kernel" "$W/vendor_boot/kernel"; do
    [[ -s "$c" ]] && { KERNEL_SRC="$c"; break; }
done
[[ -n "$KERNEL_SRC" ]] || die "could not locate the kernel Image in boot/vendor_boot"
cp -f "$KERNEL_SRC" "$KTREE/kernel"
chmod 644 "$KTREE/kernel"
KERNEL_VER="$(strings "$KTREE/kernel" 2>/dev/null | grep -m1 '^Linux version ' | awk '{print $3}' || true)"
echo "   kernel: $KERNEL_SRC -> $KTREE/kernel (${KERNEL_VER:-unknown})"

# ---------------------------------------------------------------------------
# 2. vendor ramdisk modules
# ---------------------------------------------------------------------------
mkdir -p "$KTREE/vendor_ramdisk"
rm -f "$KTREE/vendor_ramdisk"/*.ko "$KTREE/vendor_ramdisk"/modules.* 2>/dev/null || true

shopt -s nullglob
frags=("$W"/vendor_boot/vendor_ramdisk*)
shopt -u nullglob
[[ ${#frags[@]} -gt 0 ]] || die "no vendor ramdisk found in vendor_boot.img"

for frag in "${frags[@]}"; do
    [[ -f "$frag" ]] || continue
    ftype="$(file -b "$frag")"
    if [[ "$ftype" != *LZ4* && "$ftype" != *cpio* ]]; then
        echo "   skip $(basename "$frag") (not lz4/cpio: ${ftype%% *})"
        continue
    fi
    raw="$W/$(basename "$frag").cpio"
    if [[ "$ftype" == *LZ4* ]]; then
        "$LZ4" -d -f "$frag" "$raw" >/dev/null 2>&1 || die "lz4 decompress failed: $frag"
    else
        cp -f "$frag" "$raw"
    fi
    file -b "$raw" | grep -qi 'cpio' || { echo "   skip $(basename "$frag") (not cpio)"; continue; }
    d="$W/ramdisk_$(basename "$frag")"
    mkdir -p "$d"
    ( cd "$d" && "$CPIO" -idm --no-absolute-filenames --quiet ) < "$raw"
    moddir="$d/lib/modules"
    [[ -d "$moddir" ]] || { echo "   $(basename "$frag"): no lib/modules"; continue; }
    cp -f "$moddir"/*.ko "$KTREE/vendor_ramdisk/" 2>/dev/null || true
    for f in modules.load modules.load.recovery modules.blocklist; do
        [[ -f "$moddir/$f" ]] && cp -f "$moddir/$f" "$KTREE/vendor_ramdisk/$f"
    done
    echo "   vendor ramdisk: $(basename "$frag") -> $(ls "$KTREE/vendor_ramdisk"/*.ko 2>/dev/null | wc -l) modules"
done

[[ -f "$KTREE/vendor_ramdisk/modules.load" ]] || die "vendor_ramdisk/modules.load missing"

# ---------------------------------------------------------------------------
# 3. DTBs + dtbo image
# ---------------------------------------------------------------------------
if [[ -s "$W/vendor_boot/dtb" ]]; then
    echo ">> splitting vendor_boot dtb blob"
    "$PYTHON3" - "$W/vendor_boot/dtb" "$KTREE/dtb" <<'PYEOF'
import os, struct, sys

MAGIC = b'\xd0\x0d\xfe\xed'

def fdt_model(blob):
    (magic, totalsize, off_struct, off_strings, off_rsvmap, version,
     last_comp, boot_cpuid, size_strings, size_struct) = struct.unpack('>10I', blob[:40])
    assert magic == 0xd00dfeed, 'bad FDT magic'
    align4 = lambda p: (p + 3) & ~3
    pos, depth, model = off_struct, 0, None
    end_struct = off_struct + size_struct
    while pos + 4 <= end_struct:
        tok = struct.unpack('>I', blob[pos:pos+4])[0]; pos += 4
        if tok == 1:                                  # FDT_BEGIN_NODE
            end = blob.index(b'\0', pos); pos = align4(end + 1); depth += 1
        elif tok == 2:                                # FDT_END_NODE
            depth -= 1
            if depth == 0:
                break
        elif tok == 3:                                # FDT_PROP
            length, nameoff = struct.unpack('>II', blob[pos:pos+8]); pos += 8
            if depth == 1 and model is None:
                name_end = blob.index(b'\0', off_strings + nameoff)
                name = blob[off_strings+nameoff:name_end].decode('utf-8', 'replace')
                if name == 'model':
                    model = blob[pos:pos+length].rstrip(b'\0').decode('utf-8', 'replace')
            pos = align4(pos + length)
        elif tok == 4:                                # FDT_NOP
            pass
        elif tok == 9:                                # FDT_END
            break
        else:
            raise ValueError(f'bad FDT token {tok:#x} at {pos-4}')
    return model or 'unknown'

def main(src, outdir):
    data = open(src, 'rb').read()
    offs, i = [], 0
    while True:
        i = data.find(MAGIC, i)
        if i < 0:
            break
        offs.append(i); i += 4
    if not offs:
        raise SystemExit('no FDT magic in blob')
    os.makedirs(outdir, exist_ok=True)
    for old in os.listdir(outdir):
        if old.endswith('.dtb'):
            os.remove(os.path.join(outdir, old))
    for n, off in enumerate(offs, 1):
        size = struct.unpack('>I', data[off+4:off+8])[0]
        blob = data[off:off+size]
        safe = fdt_model(blob).replace(' ', '_').replace('/', '_')
        name = f'{n:02d}_dtbdump_{safe}.dtb'
        with open(os.path.join(outdir, name), 'wb') as f:
            f.write(blob)
        print(f'   {name} ({size} bytes)')
    print(f'   total: {len(offs)} DTBs')

main(sys.argv[1], sys.argv[2])
PYEOF
fi

if [[ -f "$IMAGES/dtbo.img" ]]; then
    cp -f "$IMAGES/dtbo.img" "$KTREE/dtbo.img"
    chmod 644 "$KTREE/dtbo.img"
    echo ">> dtbo.img copied"
else
    die "dtbo.img missing in $IMAGES"
fi

# ---------------------------------------------------------------------------
# 4. module images (EROFS in the stock ROM; ext4 in older/OSS builds)
# ---------------------------------------------------------------------------
extract_image() {  # <img> <dest>
    local img="$1"
    local dest="$2"
    local real="$img"
    if file -b "$img" | grep -qi 'Android sparse image'; then
        [[ -n "$SIMG2IMG" ]] || die "simg2img needed for sparse $img"
        real="$W/$(basename "$img").raw"
        "$SIMG2IMG" "$img" "$real"
    fi
    rm -rf "$dest"; mkdir -p "$dest"
    if [[ -n "$FSCK_EROFS" ]] && file -b "$real" | grep -qi 'EROFS'; then
        "$FSCK_EROFS" --extract="$dest" --overwrite --no-preserve "$real" >/dev/null 2>&1 \
            || die "fsck.erofs extract failed: $img"
    elif [[ -n "$DEBUGFS" ]] && file -b "$real" | grep -qiE 'ext[234] filesystem'; then
        ( cd "$dest" && "$DEBUGFS" -R "rdump / ." "$real" >/dev/null 2>&1 ) \
            || die "debugfs rdump failed: $img"
    else
        die "don't know how to extract $img ($(file -b "$real"))"
    fi
}

echo ">> extracting vendor_dlkm"
extract_image "$IMAGES/vendor_dlkm.img" "$W/vendor_dlkm"
mkdir -p "$KTREE/vendor_dlkm"
rm -f "$KTREE/vendor_dlkm"/*.ko "$KTREE/vendor_dlkm"/modules.* 2>/dev/null || true
cp -f "$W/vendor_dlkm/lib/modules"/*.ko "$KTREE/vendor_dlkm/" 2>/dev/null || true
for f in modules.load modules.blocklist; do
    [[ -f "$W/vendor_dlkm/lib/modules/$f" ]] && cp -f "$W/vendor_dlkm/lib/modules/$f" "$KTREE/vendor_dlkm/$f"
done
[[ -f "$KTREE/vendor_dlkm/modules.load" ]] || die "vendor_dlkm/modules.load missing"

echo ">> extracting system_dlkm"
extract_image "$IMAGES/system_dlkm.img" "$W/system_dlkm"
mapfile -t verdirs < <(find "$W/system_dlkm/lib/modules" -mindepth 1 -maxdepth 1 -type d ! -name flatten)
[[ ${#verdirs[@]} -eq 1 ]] || die "expected exactly one system_dlkm version dir, found: ${verdirs[*]:-none}"
VER="$(basename "${verdirs[0]}")"
rm -rf "$KTREE/system_dlkm"; mkdir -p "$KTREE/system_dlkm/$VER"
cp -a "${verdirs[0]}/." "$KTREE/system_dlkm/$VER/"
[[ -f "$KTREE/system_dlkm/$VER/modules.load" ]] || die "system_dlkm/$VER/modules.load missing"

# ---------------------------------------------------------------------------
# 5. Summary
# ---------------------------------------------------------------------------
echo
echo ">> done. $KTREE:"
printf '   kernel          %s\n' "$(stat -c '%s bytes' "$KTREE/kernel")"
printf '   dtb             %s files\n' "$(ls "$KTREE/dtb"/*.dtb 2>/dev/null | wc -l)"
printf '   dtbo.img        %s\n' "$(stat -c '%s bytes' "$KTREE/dtbo.img")"
printf '   vendor_ramdisk  %s modules\n' "$(ls "$KTREE/vendor_ramdisk"/*.ko 2>/dev/null | wc -l)"
printf '   vendor_dlkm     %s modules\n' "$(ls "$KTREE/vendor_dlkm"/*.ko 2>/dev/null | wc -l)"
printf '   system_dlkm     %s (%s modules)\n' "$VER" "$(find "$KTREE/system_dlkm/$VER" -name '*.ko' | wc -l)"
echo
echo ">> kernel version: ${KERNEL_VER:-unknown}"
echo ">> set MIRO_KERNEL_VERSION := $VER in device/xiaomi/miro/BoardConfig.mk"
