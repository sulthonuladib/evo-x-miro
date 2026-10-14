# `tools/` — stock ROM extraction

Scripts to turn the stock POCO F7 Ultra ROM into (a) mountable partition images and
(b) `device/xiaomi/miro-kernel` artifacts. Run them from the root of this repo, or
from the root of a synced Evolution X tree.

| Script | Purpose | Input → Output |
| --- | --- | --- |
| `extract-stock-rom.sh` | Dump a recovery ROM | `*-recovery-rom.zip` → `work/images/*.img` |
| `unpack-kernel-artifacts.sh` | Build the kernel tree | `work/images/` → `device/xiaomi/miro-kernel/` |

## End-to-end

```bash
# 1. Dump the recovery ROM. Produces boot/init_boot/vendor_boot/dtbo/
#    vendor_dlkm/system_dlkm plus system/vendor/odm/product/system_ext images.
tools/extract-stock-rom.sh ~/Downloads/miro-recovery-rom.zip work/images

# 2. Kernel artifacts (needs ANDROID_BUILD_TOP for unpack_bootimg).
export ANDROID_BUILD_TOP=~/evo
tools/unpack-kernel-artifacts.sh work/images device/xiaomi/miro-kernel

# 3. Generate the vendor trees. `extract-files.py` takes the dump dir as a
#    positional argument and extracts the images in place — it does NOT need the
#    partitions copied into the source-tree root.
cd ~/evo/device/xiaomi/miro          && ./extract-files.py  "$OLDPWD/../work/images"
cd ~/evo/device/xiaomi/sm8750-common && ./extract-files.py  "$OLDPWD/../work/images"
# then regenerate the makefiles
cd ~/evo/device/xiaomi/miro          && ./setup-makefiles.py
cd ~/evo/device/xiaomi/sm8750-common && ./setup-makefiles.py
```

`work/images` is a valid `extract_utils` "dump dir": the tool reads the `.img` files
there and extracts `system/`, `vendor/`, `odm/`, `product/`, `system_ext/` itself.

## Fastboot ROM

A fastboot ROM gives you the firmware images (xbl, abl, tz, modem, dsp, …) that the
recovery ROM does not. Use `proprietary-firmware.txt` + `extract_utils` (`--extract-factory`)
to build `vendor/xiaomi/miro-firmware`, and flash the stock fastboot ROM once to establish
the correct firmware baseline before the first custom build. Reference:
`xiaomi-haotian-devs/android_device_xiaomi_haotian/proprietary-firmware.txt`.

## Requirements

- `unzip`, `curl`
- `payload-dumper-go` (auto-fetched via `go install`, or download a release)
- AOSP `unpack_bootimg.py` (from a synced tree, `system/tools/mkbootimg/`)
- `e2fsprogs` (`debugfs`) and/or root for loop mounts; `erofs-utils` for EROFS images
