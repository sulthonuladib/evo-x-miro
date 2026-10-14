#!/usr/bin/env bash
#
# Populate device/xiaomi/miro-kernel from the partition images produced by
# tools/extract-stock-rom.sh.
#
# Usage:
#   tools/unpack-kernel-artifacts.sh <images-dir> [kernel-tree]
#
# <images-dir> must contain boot.img, dtbo.img, vendor_boot.img,
# vendor_dlkm.img, system_dlkm.img (as dumped by payload-dumper-go).
#
# Needs: AOSP unpack_bootimg (system/tools/mkbootimg), and either root (loop
# mount) or `debugfs` to read ext4 module images. EROFS needs erofs-utils.
#
set -euo pipefail

IMAGES="${1:?usage: $0 <images-dir> [kernel-tree]}"
KTREE="${2:-device/xiaomi/miro-kernel}"

[[ -d "$IMAGES" ]] || { echo "!! no such dir: $IMAGES" >&2; exit 1; }

mkdir -p "$KTREE"/{dtb,vendor_ramdisk,vendor_dlkm,kernel-headers}

# ---------------------------------------------------------------------------
# Locate unpack_bootimg
# ---------------------------------------------------------------------------
UNPACK_BOOTIMG=""
for c in \
    "${ANDROID_BUILD_TOP:-}/system/tools/mkbootimg/unpack_bootimg.py" \
    "${ANDROID_BUILD_TOP:-}/tools/mkbootimg/unpack_bootimg.py" \
    "$(command -v unpack_bootimg 2>/dev/null || true)"; do
    [[ -n "$c" && -e "$c" ]] && { UNPACK_BOOTIMG="$c"; break; }
done
[[ -n "$UNPACK_BOOTIMG" ]] || {
    echo "!! unpack_bootimg not found. Set ANDROID_BUILD_TOP to a synced source tree." >&2
    exit 1
}

W="$KTREE/.work"
mkdir -p "$W"

# ---------------------------------------------------------------------------
# 1. kernel + vendor ramdisk from boot.img / vendor_boot.img / init_boot.img
# ---------------------------------------------------------------------------
echo ">> unpacking boot / vendor_boot / init_boot"
for img in boot vendor_boot init_boot; do
    [[ -f "$IMAGES/$img.img" ]] || { echo "   skip $img.img (missing)"; continue; }
    mkdir -p "$W/$img"
    "$UNPACK_BOOTIMG" --boot_img "$IMAGES/$img.img" --out "$W/$img" --format=mkbootimg >/dev/null
done

# The raw arm64 Image is in the boot (or vendor_boot for GKI) output.
if [[ -f "$W/boot/kernel" ]]; then
    cp -f "$W/boot/kernel" "$KTREE/kernel"
elif [[ -f "$W/vendor_boot/kernel" ]]; then
    cp -f "$W/vendor_boot/kernel" "$KTREE/kernel"
else
    echo "!! could not locate the kernel Image" >&2
fi

# Vendor ramdisk (contains modules.load etc.)
for d in "$W/vendor_boot/vendor_ramdisk" "$W/init_boot/ramdisk" "$W/boot/ramdisk"; do
    [[ -d "$d" ]] && { echo ">> vendor ramdisk from $d"; cp -a "$d"/. "$KTREE/vendor_ramdisk"/ ; }
done

# ---------------------------------------------------------------------------
# 2. DTBs + dtbo image
# ---------------------------------------------------------------------------
echo ">> dtbo"
[[ -f "$IMAGES/dtbo.img" ]] && cp -f "$IMAGES/dtbo.img" "$KTREE/dtbo.img"

# ---------------------------------------------------------------------------
# 3. vendor_dlkm / system_dlkm modules
# ---------------------------------------------------------------------------
# Convert sparse images if needed, then mount read-only.
need_simg2img() { file "$1" | grep -qi 'Android sparse image'; }

mount_ext4() {  # <img> <dest>
    local img="$1" dest="$2" real="$img"
    if need_simg2img "$img"; then
        command -v simg2img >/dev/null || { echo "!! simg2img missing"; return 1; }
        real="$W/$(basename "$img").raw"; simg2img "$img" "$real"
    fi
    mkdir -p "$dest"
    if command -v debugfs >/dev/null 2>&1; then
        # non-root copy of the whole tree
        ( cd "$dest" && debugfs -R "rdump / ." "$real" >/dev/null 2>&1 ) || {
            echo "!! debugfs rdump failed for $img"; return 1; }
    else
        echo "!! debugfs missing; install e2fsprogs"; return 1
    fi
}

for part in vendor_dlkm system_dlkm; do
    [[ -f "$IMAGES/$part.img" ]] || { echo "   skip $part.img (missing)"; continue; }
    echo ">> $part"
    rm -rf "$W/$part"; mount_ext4 "$IMAGES/$part.img" "$W/$part"
    # find modules.load / blocklist wherever they landed
    find "$W/$part" -name 'modules.load'          -exec cp -f {} "$KTREE/$part/../$part/" \; 2>/dev/null || true
done

echo
echo ">> NOTE: module trees are staged under $W — move *.ko into $KTREE/vendor_dlkm"
echo "         and $KTREE/system_dlkm/<MIRO_KERNEL_VERSION>/ manually if the"
echo "         automatic layout did not match (EROS/EROFS images need erofs-utils)."
echo ">> Then update MIRO_KERNEL_VERSION in device/xiaomi/miro/BoardConfig.mk."
