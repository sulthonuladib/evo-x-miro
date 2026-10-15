# HANDOFF — Evolution X `cnb` on `miro`

> **Session handoff.** Written 2026-10-15 ~15:30 after the 3rd build attempt failed.
> Read this first, then `PLAN.md` → "Current status".

## Goal right now

Get `m -j6 evolution` to produce `out/target/product/miro/EvolutionX-*.zip`.
The vendor-tree regeneration is **done and committed**; the remaining work is a short
tail of compile/config fixes. Then Phase 5 (flash/boot).

## Where the build got to

| Run | Log | Result |
| --- | --- | --- |
| 1 | `build-evolution{,2,3}.log` | 55% — duplicate `genfscon sysfs /class/qcom-battery` |
| 2 | `build-evolution4.log` | dex2oat boot-image crash (`type_id != nullptr`) — wrong boot-jar order |
| 3 | `build-evolution5.log` | **`libipanat`: `fatal error: 'linux/msm_ipa.h' file not found`** |

Run 3 reached ~29% of the remaining graph before failing at 15:20. `out/` is ~? (df showed
24 GB free; the `miro-work` dump is still on disk and can be deleted if needed).

### Fixes already applied and committed

- **Vendor trees regenerated** from OS3.0.302.0 (kit `3d61904`/`f9677eb`; vendor
  `3b22413` miro, `4d24ec0` common; nested common `0b106b2`/`5219eb6`). `m -j6 nothing`
  passes. See `PLAN.md` → Current status for the full list (195 source-built dupes removed,
  qcwcn import, frame-manager move, `DISABLE_DEPS` on 15 AIDL-mixing blobs, V6 audio types
  `_xiaomi` variant, protobuf/boringssl/linker.config/graphicbuffersource dropped).
- **Failure 1 fix** (QTI sepolicy, **local-only, not in the kit**):
  commented out `genfscon sysfs /class/qcom-battery u:object_r:vendor_sysfs_battery_supply:s0`
  at `device/qcom/sepolicy_vndr/sm8750/generic/vendor/common/genfs_contexts:192` (backup
  `/tmp/qti_genfs_contexts.orig`). The Xiaomi tree's `.te` rules use
  `vendor_sysfs_qcom_battery`.
- **Failure 2 fix** (committed): moved `PRODUCT_BOOT_JARS += telephony-ext
  xiaomi-telephony-stub` out of `device/xiaomi/sm8750-common/common.mk` and to the end of
  `device/xiaomi/miro/lineage_miro.mk`, so they append after the AOSP base products.
  `get_build_var PRODUCT_BOOT_JARS` now starts with `com.android.art:core-oj`.

## Failure 3 — the next thing to fix

```
hardware/qcom-caf/sm8750/dataipa/ipanat/inc/ipa_nat_utils.h:71:10:
fatal error: 'linux/msm_ipa.h' file not found
FAILED: //hardware/qcom-caf/sm8750/dataipa/ipanat:libipanat ...
```

- The header exists locally at
  `hardware/qcom-caf/sm8750/dataipa/drivers/platform/msm/include/uapi/linux/msm_ipa.h`.
- `libipanat` (`hardware/qcom-caf/sm8750/dataipa/ipanat/Android.bp`) declares
  `header_libs: ["device_kernel_headers", "qti_kernel_headers", "qti_ipa_kernel_headers"]`.
- Those modules are defined in `hardware/qcom-caf/common/Android.bp` and all just use
  `defaults: ["generated_kernel_header_defaults"]`, which only exports the audio include
  dirs from `device/xiaomi/miro-kernel/prebuilt_kernel_headers.tar.gz`
  (see `vendor/lineage/build/soong/Android.bp` lines ~40–96). Nothing exports the QTI
  dataipa `uapi` path, and the prebuilt kernel headers do **not** contain `msm_ipa.h`.

**Proposed fix (choose one):**
1. Patch `hardware/qcom-caf/common/Android.bp`'s `qti_ipa_kernel_headers` to add
   `export_include_dirs: ["hardware/qcom-caf/sm8750/dataipa/drivers/platform/msm/include/uapi"]`
   (needs `header_libs`/`export_include_dirs` + correct `-I` propagation), or
2. Add the QTI dataipa `uapi/linux/*.h` (and other QTI kernel uapi headers the tree needs)
   into `device/xiaomi/miro-kernel/prebuilt_kernel_headers.tar.gz` and re-run the kernel
   artifact step in `tools/unpack-kernel-artifacts.sh`, or
3. Add a small `cc_library_headers` in the miro/common device tree that exports the dataipa
   `uapi` dir and make `libipanat`'s `header_libs` reach it (would require patching the QTI
   `Android.bp` anyway).

Option 1 is the smallest; it is another **third-party QTI patch** to note alongside the
sepolicy one.

## Reproducibility gaps to close (before a fresh `repo sync`)

Everything below is a local working-tree edit, not upstream/committed anywhere the sync
restores:
1. `device/qcom/sepolicy_vndr/sm8750/generic/vendor/common/genfs_contexts` (failure 1).
2. **Done:** `device/xiaomi/sm8750-common` is forked to
   `sulthonuladib/android_device_xiaomi_sm8750-common` (`cnb` = `5219eb6`) and
   `manifest/miro.xml` now points that project at the fork.
3. The QTI `dataipa` header fix (failure 3), once chosen.

Pushed/committed 2026-10-15: kit `d78c370` (+manifest), `device/xiaomi/miro`
`sulthonuladib/android_device_xiaomi_miro` `cnb` `1a9ce4e`, vendor
`vendor/xiaomi/{miro,sm8750-common}` `cnb` (`3b22413`/`4d24ec0`), common fork
`5219eb6`.

## Next commands

```bash
cd /mnt/games/evo
tail -f build-evolution5.log            # last run; a new run, if started, will differ
# make a fix, then:
. build/envsetup.sh && lunch lineage_miro-userdebug && USE_CCACHE=0 m -j6 evolution
# if only a list/extract-files.py changed, regenerate from the still-present dump:
#   (cd device/xiaomi/miro && ./extract-files.py /mnt/games/miro-work/images)
df -h /mnt/games                        # if <15 GB free:
#   rm -rf /mnt/games/miro-work         # ~11 GB (re-dump from /home/sulthonuladib/stock-roms)
#   rm -rf /mnt/games/evo/.repo/project-objects   # ~78 GB, keep .repo/manifests.git
```

## Key paths

| What | Where |
| --- | --- |
| Kit | `~/personal/evo-x-miro` |
| Build tree | `/mnt/games/evo` |
| Build logs | `/mnt/games/evo/build-evolution{,2,3,4,5}.log` |
| OS3 dump (still present) | `/mnt/games/miro-work/images` |
| Stock ROMs | `/home/sulthonuladib/stock-roms/` |
| extract-utils | `/mnt/games/evo/tools/extract-utils` |

## Session scratch (safe to delete)

`/tmp/miro_paths.txt`, `/tmp/soong_patches.json`, `/tmp/disabled_deps.json`,
`/tmp/*.bp.mangled`, `/tmp/qti_genfs_contexts.orig`.
