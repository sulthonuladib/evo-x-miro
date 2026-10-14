# `vendor/xiaomi/miro`

Generated proprietary-files tree for the POCO F7 Ultra. **Do not hand-write blobs** —
generate this with the LineageOS `extract_utils` tooling from the stock ROM.

## What goes here

```
vendor/xiaomi/miro/
├── BoardConfigVendor.mk          # generated
├── miro-vendor.mk                # generated
├── Android.bp / Android.mk       # generated
├── proprietary-files.txt         # the file list (checked in)
├── extract-files.py              # extract_utils driver (checked in)
├── setup-makefiles.py            # -> `./extract-files.py --regenerate_makefiles`
└── <vendor blobs>                # generated, large, usually pushed to a separate repo
```

`vendor/xiaomi/sm8750-common` is generated the same way, from
`device/xiaomi/sm8750-common/proprietary-files.txt`.

## Generate

From the root of the synced Evolution X tree, after `tools/extract-stock-rom.sh`
has produced `work/images`:

```bash
cd device/xiaomi/miro
./extract-files.py /path/to/work/images   # dump dir — extracted in place
./setup-makefiles.py                      # regenerate makefiles

cd ../sm8750-common
./extract-files.py /path/to/work/images
./setup-makefiles.py
```

`extract-files.py`'s positional argument is the source: `adb` (default, pulls from a
connected device), a directory (a "dump dir"), or a factory-image URL. Passing the
images directory lets the tool extract `system/`, `vendor/`, `odm/`, `product/`,
`system_ext/` itself — it does not need them copied into the source-tree root.

## Seed file list

A first-cut `proprietary-files.txt` for `miro` already exists in the public dump
`Jiovanni-dump/poco_miro_dump` (4,768 lines, from `OS2.0.107.0.VOMMIXM`). Import it, then
prune/fix:

```bash
curl -L -o proprietary-files.txt \
  'https://raw.githubusercontent.com/Jiovanni-dump/poco_miro_dump/missi-user-15-AQ3A.240829.003-OS2.0.107.0.VOMMIXM-release-keys/aosp-device-tree/proprietary-files.txt'
```

Expect to trim Xiaomi-only files (HyperOS framework, `mi_ext` overlays) and to add
`blob_fixups` in `extract-files.py` (symbol versioning, `add_needed` shims — see the
`xiaomi-haotian-devs` and `xiaomi-dada` trees for examples).

## Notes for miro specifically

- **Ultrasonic fingerprint:** blobs are `odm/lib64/hw/fingerprint.goodix_us.so` and
  `odm/lib64/libgf_hal.so`, plus `vendor.xiaomi.hardware.fingerprintextension*`. The AIDL
  HAL itself comes from `device/xiaomi/sm8750-common/fingerprint`.
- **IR blaster:** `odm/lib64/hw/consumerir.qcom.so` + `odm/bin/xiaomi_ir_test`.
- **Camera:** `vendor.qti.camera.provider-service_64`, `camera.qcom.sm8750.so`, and the
  Xiaomi `dynamiccameraserver` blobs.
- **Dolby / Leica audio:** redistribution may be restricted. Decide early whether to ship
  Dolby blobs or drop them (some trees drop `hardware/dolby` for licensing reasons).
