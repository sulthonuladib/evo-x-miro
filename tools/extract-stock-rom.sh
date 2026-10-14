#!/usr/bin/env bash
#
# Extract a POCO F7 Ultra (miro) stock *recovery* ROM into partition images.
#
# Usage:
#   tools/extract-stock-rom.sh /path/to/miro-recovery-rom.zip [output-dir]
#   tools/extract-stock-rom.sh /path/to/payload.bin       [output-dir]
#
# Produces <output-dir>/ with boot.img, init_boot.img, vendor_boot.img, dtbo.img,
# recovery.img, system.img, vendor.img, product.img, system_ext.img, odm.img,
# vendor_dlkm.img, system_dlkm.img, vbmeta*.img ...
#
# Needs: unzip, curl, and payload-dumper-go (auto-downloaded into tools/bin).
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HERE/bin"
PDG="$BIN/payload-dumper-go"

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <recovery-rom.zip|payload.bin> [output-dir]" >&2
    exit 1
fi

INPUT="$1"
OUT="${2:-$PWD/stock-images}"
WORK="$OUT/.work"

mkdir -p "$OUT" "$WORK" "$BIN"

# ---------------------------------------------------------------------------
# 1. Obtain payload-dumper-go if missing
# ---------------------------------------------------------------------------
if [[ ! -x "$PDG" ]]; then
    echo ">> payload-dumper-go not found, trying to fetch it"
    if command -v go >/dev/null 2>&1; then
        GOBIN="$BIN" go install github.com/ssut/payload-dumper-go@latest
        mv "$BIN/payload-dumper-go" "$PDG" 2>/dev/null || true
    fi
fi
if [[ ! -x "$PDG" ]]; then
    echo "!! Could not obtain payload-dumper-go." >&2
    echo "   Install Go, then: GOBIN='$BIN' go install github.com/ssut/payload-dumper-go@latest" >&2
    echo "   or download a release binary from https://github.com/ssut/payload-dumper-go/releases" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. Locate payload.bin
# ---------------------------------------------------------------------------
if [[ "$INPUT" == *.bin ]]; then
    PAYLOAD="$INPUT"
else
    echo ">> unzipping payload.bin from $INPUT"
    unzip -o -q "$INPUT" payload.bin -d "$WORK"
    PAYLOAD="$WORK/payload.bin"
fi

if [[ ! -f "$PAYLOAD" ]]; then
    echo "!! payload.bin not found (is this a recovery ROM?)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Dump partitions
# ---------------------------------------------------------------------------
echo ">> dumping partitions to $OUT"
"$PDG" -o "$OUT" "$PAYLOAD"

echo
echo ">> done. images:"
ls -1 "$OUT"/*.img 2>/dev/null | sed "s#^#   #"

echo
echo "Next: tools/unpack-kernel-artifacts.sh '$OUT' device/xiaomi/miro-kernel"
