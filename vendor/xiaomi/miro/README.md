# `vendor/xiaomi/miro`

Generated proprietary-files tree for the POCO F7 Ultra. **Do not hand-write blobs** —
generate this with the LineageOS `extract_utils` tooling from the stock ROM.

## What goes here

```
vendor/xiaomi/miro/
├── BoardConfigVendor.mk          # generated
├── miro-vendor.mk                # generated
├── Android.bp / Android.mk       # generated
└── <vendor blobs>                # generated, large, usually pushed to a separate repo
```

The inputs are checked into the **device tree** (this is the LineageOS convention):
`device/xiaomi/miro/proprietary-files.txt`, `extract-files.py` and
`setup-makefiles.py`. `vendor/xiaomi/sm8750-common` is generated the same way from
the `device/xiaomi/sm8750-common` tree.

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

## File list

`device/xiaomi/miro/proprietary-files.txt` (2,842 entries) was seeded from the public dump
`Jiovanni-dump/poco_miro_dump` (4,768 lines, `OS2.0.107.0.VOMMIXM`) and then re-checked
against the OS3.0.302.0.WOMIDXM partitions. The extraction run corrected what the seed
missed:

- 42 entries owned by `device/xiaomi/sm8750-common` were dropped (they are generated from
  the common tree's list; keeping them defined duplicate Soong modules),
- 30 HIDL interface libs that the A17 source builds were dropped (`system_ext`/`product`
  copies the common tree already defines at `vendor`, plus the real Adreno files behind its
  symlinks),
- 7 `system/system/...` entries that used an extra `system/` level were fixed,
- 477 camera/ADSP entries were curated from `proprietary-files-os3-candidates.txt` (camera
  configs and CamX/SNPE/ADSP libs); 14 vendor→odm symlinks were re-expressed with
  `;SYMLINK=`.

`device/xiaomi/miro/proprietary-files-os3-candidates.txt` (3,515 files) is the pre-curation
snapshot of the OS3 files that were in neither list (compiled app artifacts excluded).
Regenerate it when processing a new dump. Add `blob_fixups` to
`device/xiaomi/miro/extract-files.py` as `check_elf` reports unresolved `NEEDED` entries.

## Notes for miro specifically

- **Ultrasonic fingerprint:** blobs are `odm/lib64/hw/fingerprint.goodix_us.so` and
  `odm/lib64/libgf_hal.so`, plus `vendor.xiaomi.hardware.fingerprintextension*`. The AIDL
  HAL itself comes from `device/xiaomi/sm8750-common/fingerprint`.
- **IR blaster:** `odm/lib64/hw/consumerir.qcom.so` + `odm/bin/xiaomi_ir_test`.
- **Camera:** `vendor.qti.camera.provider-service_64`, `camera.qcom.sm8750.so`, and the
  Xiaomi `dynamiccameraserver` blobs.
- **Dolby / Leica audio:** redistribution may be restricted. Decide early whether to ship
  Dolby blobs or drop them (some trees drop `hardware/dolby` for licensing reasons).
