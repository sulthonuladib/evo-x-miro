# PLAN.md — `miro` × Evolution X (Android 17 / `cnb`)

Phased roadmap from where we are to a **flashable, self-updating ROM**. A new session should
read `AGENTS.md` first, then the "Current status" block below, then jump to the active phase.

## Status legend

`✅ done` · `🟡 in progress` · `⬜ not started` · `⛔ blocked` (needs an input)

## Current status

- **Active phase:** Phase 4 (first build). Phases 0–3 are done and **Phase 1 (source sync) is
  complete** — the `cnb` tree at `/mnt/games/evo` is fully synced (`repo-sync2.log` ends with
  "repo sync has finished successfully"; the four previously-failed projects
  `platform/system/unwinding`, `platform/external/perfmark`, `platform/external/python/cpython3`,
  `platform/external/skia` are all checked out).
- **Phase 4 prep done (2026-10-15):**
  - Signing keys generated at `vendor/evolution-priv/keys` via the template's `keys.sh`
    (clone `Evolution-X/vendor_evolution-priv_keys-template`); ~179 key files incl.
    `avb_custom_key.bin`. `vendor/lineage/config/evolution.mk` picks them up; for
    `EVO_BUILD_TYPE=Unofficial` it is an optional `-include`.
  - Host has `gpg 2.4.9`, `gperf`, `schedtool` (the `gnupg` meta package is *not* installed and
    `sudo` needs a password, but `gpg` is present so the build is fine).
  - Disk freed to ~103 GB on `/mnt/games` (`miro-work` removed; stock ROMs moved to
    `/home/sulthonuladib/stock-roms/`). **`.repo` (~78 GB) is kept** so `repo` still works;
    prune it only if `out/` drives `/mnt/games` below ~15 GB free.
  - Lunch target: `lineage_miro-userdebug` → `EvolutionX-17.0-20261015-miro-12.3-Unofficial`
    (`PLATFORM_VERSION=17`, `TARGET_DEVICE=miro`, `WITH_GMS=true`).
- **Blocker found at first Soong analysis (2026-10-15):** the OS3 vendor trees are **incomplete
  and inconsistent**, so `m -j6 evolution` never gets past Soong. The build tree
  `/mnt/games/evo` was patched in place to prove this out (uncommitted; do not trust it), but the
  correct fix is to **regenerate** the vendor trees from the full OS3 dump. Root causes:
  1. `device/xiaomi/miro/proprietary-files.txt` is missing dozens of OS3 blobs present in the
     stock `odm`/`vendor`/`system_ext` images (e.g. `libmpbase`, `libchilog`, the Xiaomi camera
     stack, and many `vendor.xiaomi.*-V*-ndk` AIDL libs). 71 such paths were identified and
     appended to the kit's list; the 3,037-entry `proprietary-files-os3-candidates.txt` still
     needs full reconciliation.
  2. Both vendor `Android.bp` `soong_namespace` blocks are missing
     `"hardware/qcom-caf/wlan/qcwcn"`; without it, miro/common modules cannot see the source
     `libwifi-hal-ctrl`, and restoring the prebuilt causes a namespace-duplicate error.
  3. ~195 miro vendor modules duplicate source modules (AOSP/QTI) and must be dropped from
     `proprietary-files.txt`, not patched out of the generated `Android.bp`. Removing them
     wholesale by name is wrong (some, e.g. `libwifi-hal-ctrl`, have no enabled source and the
     prebuilt is required).
  4. Some libs needed by the common tree (`libframemaster*`, `libfcmintf`,
     `vendor.xiaomi.hardware.frame*-V1-ndk`) are `system_ext` blobs that belong in the common
     vendor tree, not miro.
- **Next action (regenerate vendor trees, then build):** the full OS3 dump is cached at
  `/mnt/games/miro-work/images` (all partitions from the OS3 OTA `payload.bin`):
  ```bash
  export PATH="$HOME/.local/bin:$HOME/.local/opt/erofs/usr/bin:$PATH"
  cd /mnt/games/evo
  # 1) reconcile device/xiaomi/miro/proprietary-files.txt (and the common list) against
  #    proprietary-files-os3-candidates.txt; drop source-built dupes, add the missing blobs
  # 2) add hardware/qcom-caf/wlan/qcwcn to namespace_imports in
  #    device/xiaomi/{miro,sm8750-common}/extract-files.py
  # 3) regenerate the vendor trees (see docs/build-cnb.md / tools/README.md):
  (cd device/xiaomi/miro          && ./extract-files.py /mnt/games/miro-work/images && ./setup-makefiles.py)
  (cd device/xiaomi/sm8750-common && ./extract-files.py /mnt/games/miro-work/images && ./setup-makefiles.py)
  # 4) commit + push vendor/xiaomi/{miro,sm8750-common}; re-sync the build tree
  # 5) USE_CCACHE=0 m -j6 evolution
  ```
- **Phase 2 results (OS3.0.302.0.WOMIDXM, 2026-10-14):**
  - Kernel: **`6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k`** (the OS2.0.107.0 dump's
    6.6.30 is stale); `MIRO_KERNEL_VERSION` updated; artifacts populated in
    `device/xiaomi/miro-kernel/` (kernel, 8 DTBs, dtbo.img, 411 ramdisk modules, 380
    vendor_dlkm modules, 96 system_dlkm modules).
  - SPL **2026-08-01** (`1785542400`); `device/xiaomi/miro/BoardConfig.mk` overrides the
    common tree's stale `2026-02-01` AVB rollback indexes after the include.
  - Super: **11 GiB** (`11811160064` / dynamic `11809841488`) per the OS3.0.302.0 fastboot
    GPT — the common-tree default is correct; the old 8.5 GiB dump values are stale.
  - TZ `TZ.XF.5.29-00450-PAKALA-1.111359.5`; build
    `16OS3.1.260730.110026679.QCPEGL.S` (2026-07-30).
- **Inputs:**
  - ✅ **Stock ROM** — at `/mnt/games/miro-files/`:
    - recovery: `miro_id_global-ota_full-OS3.0.302.0.WOMIDXM-user-16.0-e2b69f85e9.zip` (`payload.bin`, 7.5 GB)
    - fastboot: `miro_id_global_images_OS3.0.302.0.WOMIDXM_..._16.0_id_*.tgz` (9.2 GB, `images/` + `flash_all.sh`)
    - baseline is **Android 16 / HyperOS 3** (newer than the OS2.0.107.0 dump the scaffold used).
  - ⛔ **Build host** — ~250–400 GB disk, ~64 GB RAM. `/mnt/games` has 277 GB free; workable for a
    single-target build if `out/` lives there and ccache is off, but tight for source + `out` together.
  - ✅ **GitHub org** — `sulthonuladib`; `origin` remote set, manifest + OTA URLs updated. The
    `android_device_xiaomi_miro{,-kernel}` and `proprietary_vendor_xiaomi_{miro,sm8750-common}`
    repos are published on `cnb` (see Phase 3).

## Definition of done — "we can flash the ROM"

1. A signed `EvolutionX-17.0-*-miro-*-Unofficial.zip` builds from a synced `cnb` tree.
2. It installs via fastboot `recovery.img` + recovery sideload on a real `miro`.
3. It boots to a usable Android 17 home screen.
4. Every marquee feature is either working or explicitly documented as broken
   (fingerprint, RIL/IMS, WLAN/BT/NFC, display, camera, IR, charging, haptics).
5. SELinux enforcing; Play Integrity status known.
6. An OTA update flashes over it and boots (dirty flash).

## Decisions log

| # | Decision | Rationale |
| --- | --- | --- |
| D1 | Target Evolution X **`cnb`** (Android 17) | Current dev branch; SM8750 already supported on A17 (LOS 24 + `Crisp-los` `cnb`). |
| D2 | Base on `Crisp-los/android_device_xiaomi_sm8750-common` `cnb` | Full A17 Xiaomi SM8750 common tree; already has a `miro` code path. |
| D3 | Kernel **prebuilt-from-stock** first (Strategy A) | Guarantees KMI/ABI match; fastest path to boot. Source build (Strategy B) later. |
| D4 | Firmware **firmwareless by default** | Upstream default; avoids anti-rollback footguns. Firmware-in-OTA is opt-in later. |
| D5 | Build host, not this laptop | A17 needs ~250–400 GB disk and ~64 GB RAM. |
| D6 | Keep device facts in `docs/`, kit points at them | Single source of truth (`AGENTS.md` conventions). |

---

## Phase 0 — Research & scaffolding ✅

**Deliverables (all present):** `docs/evolution-x-miro-bringup.md`, `docs/build-cnb.md`,
`docs/maintenance.md`, `manifest/miro.xml`, `device/xiaomi/miro/*`,
`device/xiaomi/miro-kernel/README.md`, `vendor/xiaomi/miro/README.md`, `tools/*`.

**Acceptance:** a new session can read `AGENTS.md` + `PLAN.md` and know the target, the base
trees, and the next action. ✅

## Phase 1 — Environment & source sync 🟡

**In progress on this machine:** `repo` 2.65 installed to `~/.local/bin`; tree initialized at
`/mnt/games/evo` with `repo init -u https://github.com/Evolution-X/manifest -b cnb
--partial-clone --clone-filter=blob:limit=10M --git-lfs`; `manifest/miro.xml` copied to
`.repo/local_manifests/`. First sync left 4 projects to finish. `git-lfs` 3.8.0 in `~/.local/bin`.

**Remaining inputs:** signing keys (`vendor/evolution-priv/keys`); host packages
`gnupg gperf schedtool`.

**Inputs:** build host; GitHub org.

| Task | Detail |
| --- | --- |
| Provision host | Ubuntu 22.04/24.04, ≥12 cores, ≥64 GB RAM, ≥300 GB fs. |
| Install `repo` + packages | see `docs/build-cnb.md` §0. |
| `repo init -b cnb` | `https://github.com/Evolution-X/manifest`. |
| Add `manifest/miro.xml` | already points at `sulthonuladib`; copy to `.repo/local_manifests/`. |
| `repo sync` | lands `device/xiaomi/sm8750-common` (`cnb`) + `hardware/xiaomi`. |
| Generate keys | `vendor/evolution-priv/keys`; **back up**. |

**Acceptance:** `repo sync` completes; `device/xiaomi/sm8750-common` and
`hardware/xiaomi` are present; keys exist.

## Phase 2 — Stock ROM acquisition & extraction ✅

**Inputs:** present — `/mnt/games/miro-files/` (`OS3.0.302.0.WOMIDXM`, Android 16 / HyperOS 3).

| Task | Command | Result |
| --- | --- | --- |
| Dump partitions | `tools/extract-stock-rom.sh <recovery.zip> work/images` | ✅ 18 GB in `/mnt/games/miro-work/images` (49 partitions incl. `mi_ext`) |
| Populate kernel tree | `tools/unpack-kernel-artifacts.sh work/images device/xiaomi/miro-kernel` | ✅ kernel + 8 DTBs + dtbo + 411/380/96 modules |
| Record kernel version | set `MIRO_KERNEL_VERSION` to the `system_dlkm/…` dir name | ✅ `6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k` |
| Verify super layout | `lpdump` (recovery/dump); confirm `9126805504` / `9122611200` | ✅ actually **11 GiB**: fastboot GPT `rawprogram0.xml` says `super` = 11534336 KiB = `11811160064`; dynamic `11809841488` (common default) |
| Firmware baseline | note SPL/TZ version from `board-info.txt` | ✅ SPL `2026-08-01` (OTA metadata); TZ `TZ.XF.5.29-00450-PAKALA-1.111359.5` (`tz.img`); `board-info.txt` is not in the vendor/odm images |

**Acceptance:** `device/xiaomi/miro-kernel/` holds `kernel`, `dtb/`, `dtbo.img`,
`vendor_ramdisk/`, `vendor_dlkm/`, `system_dlkm/<version>/` with `modules.load` files. ✅
(every `modules.load` entry resolves; module sets are byte-identical to the stock images)

## Phase 3 — Vendor trees ✅

**Depends on:** Phase 2 (done).

| Task | Detail | Status |
| --- | --- | --- |
| Seed `proprietary-files.txt` | import the public `poco_miro_dump` list, then prune | ✅ 2,472 entries seeded; extraction then revealed 42 common-owned duplicates, 30 HIDL interface libs and 7 `system/system/` prefixes to correct |
| Curate camera/ADSP | pull OS3-only blobs from `proprietary-files-os3-candidates.txt` | ✅ 477 entries imported (camera configs, CamX/SNPE/ADSP libs); 14 vendor→odm symlinks re-expressed with `;SYMLINK=` |
| Write `extract-files.py` fixups | symbol versions / `add_needed` shims | ✅ 1 miro-owned shim (`libsoundtriggerhal.qti.so` audio types V2→V3); the shared audio/display shims live in the common tree because those blobs are common-owned |
| Generate `vendor/xiaomi/miro` | `./extract-files.py <dump>` + `./setup-makefiles.py` | ✅ 1,051 modules, no duplicate module names |
| Generate `vendor/xiaomi/sm8750-common` | same, from the common tree | ✅ 1,175 modules, no duplicate module names |
| Add `BoardConfigVendor.mk` include | already wired in `BoardConfig.mk` | ✅ |

**Acceptance:** `m evolution` gets past vendor makefile resolution; no missing blobs at
`installclean`; `vendor/xiaomi/miro/miro-vendor.mk` generated. The vendor makefiles are
generated and internally consistent (no duplicate modules); the real `check_elf` pass still
needs the build host.

**Generated 2026-10-14 from OS3.0.302.0.WOMIDXM:**

- `device/xiaomi/miro/proprietary-files.txt` — 2,842 entries after de-duplication against the
  common list, `system/system/` prefix fixes, HIDL-interface pruning (the `system_ext`/`product`
  copies the common tree already defines at `vendor`) and camera/ADSP curation.
- `device/xiaomi/miro/extract-files.py` — one miro-owned `blob_fixup` plus the `lib_fixups`
  shared with the common tree.
- `vendor/xiaomi/miro/{Android.bp,Android.mk,miro-vendor.mk,BoardConfigVendor.mk}` (1,051 modules).
- `vendor/xiaomi/sm8750-common/{Android.bp,Android.mk,sm8750-common-vendor.mk,BoardConfigVendor.mk}`
  (1,175 modules).
- `proprietary-files-os3-candidates.txt` is the pre-curation snapshot (3,515 files).

**Published (github.com/sulthonuladib, default branch `cnb`):**

- `android_device_xiaomi_miro`, `android_device_xiaomi_miro-kernel`,
  `proprietary_vendor_xiaomi_miro`, `proprietary_vendor_xiaomi_sm8750-common`.
- `proprietary_vendor_xiaomi_miro` stores the three files over GitHub's 100 MB limit with
  **Git LFS** (`unet.serialized.bin`, `libarcsoft_turbo_fusion_mfnr.so`,
  `libarcsoft_raw_sr.so`); build hosts must install `git-lfs` to fetch those objects.

**Left for the build host (Phase 4):**

- Real `check_elf` triage (`check_elf_files: true` in both `Android.bp` files). Static analysis
  flags 267 `DT_NEEDED` names not provided by the blob sets; most are source-built AOSP/QTI
  interfaces (their version mismatch with older stock blobs is the usual source of fixups).
- The upstream `Crisp-los/android_device_xiaomi_sm8750-common` list still carries 11 entries
  that do not exist on `miro` (ST NFC service/configs, `libtouchreport_alg.so`, the 32-bit
  gralloc/mapper libs and the 32-bit touchfeature copy rule). They were pruned locally to
  generate the common vendor tree; fork/patch the common tree so a fresh extraction is
  reproducible.

## Phase 4 — First build ⬜

**Depends on:** Phases 1–3.

| Task | Detail |
| --- | --- |
| `lunch lineage_miro-<release>-userdebug` | pick the exact target from the `lunch` menu. |
| `m evolution` | fix compile errors against the A17 tree. |
| Inspect `ota_from_target_files` | confirm A/B payload + `miro.json` generated. |

**Acceptance:** `out/target/product/miro/EvolutionX-*.zip` + `miro.json` exist; `boot.img`,
`init_boot.img`, `vendor_boot.img`, `dtbo.img`, `recovery.img` produced.

## Phase 5 — First flash & boot ⬜

**Depends on:** Phase 4; unlocked bootloader; matching firmware baseline.

| Task | Detail |
| --- | --- |
| Flash recovery | `fastboot flash recovery recovery.img` |
| Wipe | Format data (first install). |
| Sideload ROM | `adb sideload EvolutionX-*.zip`. |
| Capture logs | `adb logcat`, `dmesg`, `avc` denials via `android-cli`. |

**Acceptance:** boots to setup wizard / home screen; no bootloop; you can capture a logcat.

## Phase 6 — Hardware bring-up ⬜

Each item: kernel driver (already in OSS kernel) → vendor HAL → perf → ROM config.

| Feature | Focus | Status |
| --- | --- | --- |
| Ultrasonic UDFPS | `sm8750-common/fingerprint` AIDL HAL + `TARGET_HAS_UDFPS` | ⬜ |
| RIL / VoLTE / VoWiFi | `ENABLE_VENDOR_RIL_SERVICE`, IMS configs | ⬜ |
| Display | 120 Hz switching, Dolby Vision, density 600 | ⬜ |
| WLAN / BT / NFC | common-tree configs, firmware symlinks | ⬜ |
| Camera | QTI provider + Xiaomi dynamic camera | ⬜ |
| IR blaster | `consumerir` HAL, `ir-spi.ko` | ⬜ |
| Charging | 120 W wired + 50 W wireless (`sc96281`) | ⬜ |
| Haptics | QTI `/sys/class/qcom-haptics` vibrator HAL | ⬜ |
| Touch / edge suppression | port `HaotianTouch`-style app | ⬜ |

**Acceptance:** every row either ✅ working or documented broken with a reason and log.

## Phase 7 — Stability, security, integrity ⬜

- SELinux **enforcing**; triage every `avc` denial.
- Battery/thermal sanity (`android-profiler`).
- Play Integrity: signed build + PIF as needed; record the verdict.
- Audit exported components/permissions (`android-permissions-security`).

**Acceptance:** no unresolved denials; device is a daily driver; integrity status documented.

## Phase 8 — OTA ⬜

| Task | Detail |
| --- | --- |
| Add Updater overlay | `device/xiaomi/miro/overlay-evolution/Updater/res/values/strings.xml`. |
| Publish | GitHub Pages/R2: `builds/miro.json` + `changelogs/miro.txt` + zip. |
| Verify | Dirty-flash an OTA end-to-end; confirm boot + data preserved. |

**Acceptance:** the Updater shows the new build and installs it successfully.

## Phase 9 — Release ⬜

- Publish the XDA thread + download links; document the firmware baseline.
- Tag the device tree / kernel / vendor repos.
- Optional: apply for Evolution X **official** maintainership
  (`docs/evolution-x-miro-bringup.md` §6.3).

## Phase 10 — Kernel from source (optional) ⬜

Build `bsp-miro-v-oss` with Kleaf (target `miro`, variant `consolidate`/`perf`); forward-port
to the current `android15-6.6` ACK tip; then enable KernelSU / upstream options.
See `docs/evolution-x-miro-bringup.md` §2.4 (Strategy B).

---

## Open questions

- Exact `lunch` release token for `cnb` (read from the `lunch` menu).
- Which Xiaomi blobs can legally ship (Dolby, Leica-flagged audio)?
- Is the public `proprietary-files.txt` list complete vs. a fresh dump? (The OS2.0.107.0
  list predates OS3.0.302.0; diff it against the fresh images in Phase 3.)
- Resolved: stock `super` **does** contain the `mi_ext` logical partition, but the custom
  build's common-tree partition list omits it — it is not needed.
- Resolved: `miro` super is 11 GiB on the OS3.0.302.0 baseline (not 8.5 GiB).

## Change log

- 2026-10-14 — Phase 0 complete; kit + docs written; target `cnb` chosen.
- 2026-10-14 — repo renamed `evo-x-miro`; `origin` remote + `.gitignore` committed;
  GitHub org resolved to `sulthonuladib`.
- 2026-10-14 — stock ROM located at `/mnt/games/miro-files/`; baseline is **Android 16 /
  HyperOS 3** (`OS3.0.302.0.WOMIDXM`), newer than the OS2.0.107.0 dump. Kernel version and
  rollback index must be re-derived from this ROM.
- 2026-10-14 — **Phase 3 started.** Seeded `device/xiaomi/miro/proprietary-files.txt`
  (2,472 device-specific entries after removing 1,512 common-owned and 613 stale ones from
  the public OS2.0.107.0 list), added `extract-files.py`/`setup-makefiles.py`, parked 3,515
  new OS3 files in `proprietary-files-os3-candidates.txt`; vendor extraction run pending a
  synced tree.
- 2026-10-14 — **Phase 3 complete.** Cloned `tools/extract-utils` + `sm8750-common`; generated
  both vendor trees from the OS3.0.302.0 images. The seeded list was corrected during the run:
  42 common-owned duplicates, 30 HIDL interface libs (source-built) and 7 `system/system/`
  prefixes removed/fixed; 477 camera/ADSP entries curated from the OS3 candidates; 14
  vendor→odm symlinks re-expressed with `;SYMLINK=`. Both `Android.bp` files now have zero
  duplicate module names. Added one miro-owned `blob_fixup` (`libsoundtriggerhal.qti.so`).
  Generated makefiles committed; blobs stay gitignored. Remaining `check_elf` triage and the
  11-entry common-tree prune are documented in Phase 3 for the build host.
- 2026-10-14 — **Phase 2 complete.** Dumped the recovery payload (49 partitions); populated
  `device/xiaomi/miro-kernel/` (kernel `6.6.118-…`, 8 DTBs, dtbo.img, 411+380+96 modules);
  `unpack-kernel-artifacts.sh` rewritten for EROFS/LZ4-cpio/FDT splitting; SPL corrected to
  `2026-08-01` and overridden in the miro BoardConfig; super corrected to 11 GiB; docs and
  AGENTS.md updated; hyperdroid skills installed under `.agents/skills/`.
