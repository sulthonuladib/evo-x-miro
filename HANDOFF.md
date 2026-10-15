# HANDOFF — Evolution X `cnb` on `miro`

> **Session handoff.** Written 2026-10-15 after the first `m evolution` attempt got stuck at
> Soong analysis. Read this first, then `PLAN.md` → "Current status". Delete/refresh once its
> contents are folded into `PLAN.md`.

## Goal right now

Get the first `m -j6 evolution` build of Evolution X (Android 17 / `cnb`) for POCO F7 Ultra
(`miro`) past **Soong analysis** and on to compilation, then triage the real `check_elf` /
missing-module errors.

Phases 0–2 are done. Phase 1 (source sync) is **done**. Phase 3 (vendor trees) is **declared
done but is actually incomplete for OS3** — see below. Phase 4 (first build) is blocked on
regenerating the vendor trees.

## Current state

- **Kit repo:** `~/personal/evo-x-miro` @ `main`. Uncommitted change:
  `device/xiaomi/miro/proprietary-files.txt` (+70 OS3 blob paths). Commit it.
- **Build tree:** `/mnt/games/evo`, branch `cnb`, fully synced
  (`repo-sync2.log` → "repo sync has finished successfully").
- **Signing keys:** `vendor/evolution-priv/keys` generated (template `keys.sh`, ~179 files,
  `avb_custom_key.bin`). **Not backed up off-machine yet.**
- **Lunch works:** `lineage_miro-userdebug` →
  `EvolutionX-17.0-20261015-miro-12.3-Unofficial` (`PLATFORM_VERSION=17`, `TARGET_DEVICE=miro`,
  `WITH_GMS=true`).
- **Full OS3 dump cached:** `/mnt/games/miro-work/images/` — all partitions dumped from
  `miro_id_global-ota_full-OS3.0.302.0.WOMIDXM...zip` `payload.bin` (odm, vendor, system_ext,
  system, product, …). `payload.bin` is at `/mnt/games/miro-work/.work/payload.bin`.
  Stock zips moved to `/home/sulthonuladib/stock-roms/`.
- **Disk:** `/mnt/games` ~90 GB free; `.repo` (~78 GB) still present. Prune it only if `out/`
  runs the disk below ~15 GB.

## The blocker (what the first build found)

`USE_CCACHE=0 m -j6 evolution` runs Soong analysis and fails with a cascade of:
- `partition is different: system(X) != vendor(prebuilt_X)` for ~195 modules where a vendor
  prebuilt duplicates an AOSP/QTI source module;
- `found in multiple namespaces(...) when including in vendor partition` for the same class
  (libraries, binaries, XML, APEX);
- `depends on undefined module "X"` for ~70 stock blobs that were never extracted.

**Do not keep patching `/mnt/games/evo/vendor/xiaomi/*/Android.bp` in place.** That was done
this session only to enumerate the missing set; those diffs are scratch and are *not* the fix.
The generated `Android.bp` must be regenerated from a corrected `proprietary-files.txt`.

### Root causes

1. **`proprietary-files.txt` is missing OS3 blobs.** The stock `odm`/`vendor`/`system_ext`
   images contain many libs the list never picked up: `libmpbase`, `libchilog`, the Xiaomi
   camera stack (`libcamlog`, `libmialgo*`, `libopencv*`, `libcom.xiaomi.*`, …), and many
   `vendor.xiaomi.*-V*-ndk` AIDL interfaces. 71 were identified and appended to the kit's
   `device/xiaomi/miro/proprietary-files.txt` (see the diff). `proprietary-files-os3-candidates.txt`
   has 3,515 entries vs 2,763 in the list — a 3,037-entry difference that still needs review.
2. **Missing namespace import.** The vendor `soong_namespace` blocks import
   `hardware/qcom-caf/wlan` but not its sub-namespace `hardware/qcom-caf/wlan/qcwcn`. Result:
   `libwifi-hal-ctrl` (source, in `qcwcn`) is invisible to the miro namespace → "undefined";
   adding the prebuilt back → "multiple namespaces". Fix in `extract-files.py`
   `namespace_imports` (add `hardware/qcom-caf/wlan/qcwcn` to **both** device and common) and
   regenerate.
3. **Source-built duplicates must be dropped from the list.** ~195 miro vendor modules shadow
   AOSP/QTI source modules. They must be removed from `proprietary-files.txt`, not deleted from
   the generated `Android.bp`. Warning: a blind name-intersection removal is wrong —
   `libwifi-hal-ctrl` (and likely others) have no *enabled* source and the prebuilt is required.
   Decide per module using the reference `Crisp-los` common tree and Soong errors.
4. **Wrong tree for some common-owned libs.** `libframemaster*`, `libfcmintf`,
   `libframecapturemanager`, `vendor.xiaomi.hardware.frame{V1-ndk,capturemanager-V1-ndk}` are
   `system_ext` blobs that the common `displayfeature.default` depends on; they belong in the
   **common** vendor tree, not miro (the common namespace cannot see the miro namespace).

## Next commands (in order)

```bash
export PATH="$HOME/.local/bin:$HOME/.local/opt/erofs/usr/bin:$PATH"
cd /mnt/games/evo

# 0) (optional) throw away the scratch in-place vendor patches
git -C vendor/xiaomi/miro           checkout -- Android.bp miro-vendor.mk
git -C vendor/xiaomi/sm8750-common  checkout -- Android.bp sm8750-common-vendor.mk
git -C device/xiaomi/miro           checkout -- proprietary-files.txt
git -C device/xiaomi/sm8750-common  checkout -- proprietary-files.txt
# (untracked *.so added under proprietary/ can stay; regeneration overwrites them)

# 1) reconcile the blob lists against proprietary-files-os3-candidates.txt
#    - add the missing OS3 blobs (the 70 already appended to the kit are a start)
#    - drop modules that are built from source (use Soong errors + the Crisp-los common tree)
#    - put system_ext common deps in the common list, not the device list

# 2) fix namespace imports in device/xiaomi/{miro,sm8750-common}/extract-files.py:
#    add 'hardware/qcom-caf/wlan/qcwcn' to namespace_imports

# 3) regenerate the vendor trees from the cached full dump
(cd device/xiaomi/miro          && ./extract-files.py /mnt/games/miro-work/images && ./setup-makefiles.py)
(cd device/xiaomi/sm8750-common && ./extract-files.py /mnt/games/miro-work/images && ./setup-makefiles.py)

# 4) commit + push vendor/xiaomi/{miro,sm8750-common} on cnb, then re-sync the build tree
#    (or copy the regenerated trees in; the build tree is a clone)

# 5) build
. build/envsetup.sh
lunch lineage_miro-userdebug
USE_CCACHE=0 m -j6 evolution > build.log 2>&1 &
```

If Soong passes, let it run and watch `/mnt/games/evo/build.log` and `df -h /mnt/games`.

## Scratch state warning

`/mnt/games/evo` currently has **large uncommitted diffs** in
`vendor/xiaomi/miro/Android.bp` (+71 libs, −195 modules), `vendor/xiaomi/sm8750-common/Android.bp`
(−4 modules), and the two `device/xiaomi/*/proprietary-files.txt` files. These were used only to
enumerate the problems. They are **not** the fix and will be replaced by regeneration. The
extracted `.so` files under `vendor/xiaomi/*/proprietary/` are untracked and reusable.

## Key paths

| What | Where |
| --- | --- |
| Kit | `~/personal/evo-x-miro` |
| Build tree | `/mnt/games/evo` (`out/` same fs) |
| Full OS3 dump | `/mnt/games/miro-work/images/` (+ `.work/payload.bin`) |
| Stock zips | `/home/sulthonuladib/stock-roms/` |
| Signing keys | `/mnt/games/evo/vendor/evolution-priv/keys` |
| Candidate list | `device/xiaomi/miro/proprietary-files-os3-candidates.txt` |
| extract-utils | `~/personal/evo-x-miro/tools/extract-utils` |
| Published repos | `github.com/sulthonuladib/*` @ `cnb` |

## Findings to keep

- **71 missing OS3 blobs** were identified (all appended to the kit's `proprietary-files.txt`):
  `libmpbase`, `libchilog`, `libcamlog`, `libAF`, `libFS`, `libITT`, `libmialgo*`,
  `libopencv*`, `libcom.xiaomi.*`, `com.qti.*`, `camera.qcom.sm8750`, and the Xiaomi AIDL
  interfaces `vendor.xiaomi.hardware.{aidlbgservice,mikeybag,misauth,mrm,videoservice,vsimapp,
  fingerprintextension,cit.wifi}-*`.
- **Source-built collisions** include `libalsautils(v2)`, `libbinderdebug`,
  `lib_android_keymaster_keymint_utils`, `wifi_legacy`, `qti-audio-types-aidl-*`,
  `vendor.qti.hardware.{camera.aon,display.*,systemhelperaidl,...}-*`, and many QTI
  binaries/XML (`hostapd`, `wpa_supplicant`, `iw`, `dumpsys`, `audioeffectservice_qti.xml`, …).
- The `cnb` tree reports `PLATFORM_VERSION_CODENAME=REL`, `PLATFORM_VERSION=17`,
  `BUILD_ID=CP2A.260605.016` (Evolution X 12.3).

## Relevant commits (kit)

- `d42de1c` — Phase 1 complete; Phase 4 prep and pre-build handoff.
- `ad70c1b` — durable session handoff for Phase 1 → Phase 4.
- `2acad2b` — Phase 3: vendor trees.
