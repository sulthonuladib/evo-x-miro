# PLAN.md — `miro` × Evolution X (Android 17 / `cnb`)

Phased roadmap from where we are to a **flashable, self-updating ROM**. A new session should
read `AGENTS.md` first, then the "Current status" block below, then jump to the active phase.

## Status legend

`✅ done` · `🟡 in progress` · `⬜ not started` · `⛔ blocked` (needs an input)

## Current status

- **Active phase:** Phase 3 (vendor trees, in progress). Phase 2 is complete; Phase 1 still needs a build host.
- **Done:** Phase 0 (research + kit) and Phase 2 (stock ROM extraction + kernel artifacts).
- **Next action:** Phase 3 — run `device/xiaomi/miro/extract-files.py /mnt/games/miro-work/images`
  from a synced `cnb` tree (needs `tools/extract-utils`), then `./setup-makefiles.py`; repeat
  for the common tree. The file list + fixups are already committed.
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
  - ✅ **GitHub org** — `sulthonuladib`; `origin` remote set, manifest + OTA URLs updated.

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

## Phase 1 — Environment & source sync ⬜⛔

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

## Phase 3 — Vendor trees 🟡

**Depends on:** Phase 2 (done). **Active now.**

| Task | Detail | Status |
| --- | --- | --- |
| Seed `proprietary-files.txt` | import the public `poco_miro_dump` list, then prune | ✅ 2,472 entries: 1,512 common-owned removed, 613 stale dropped, 29 bare paths resolved; 3,515 OS3 candidates parked in `proprietary-files-os3-candidates.txt` |
| Write `extract-files.py` fixups | symbol versions / `add_needed` shims (copy from haotian/dada) | 🟡 miro-owned audio/display shims seeded; `check_elf` will reveal more |
| Generate `vendor/xiaomi/miro` | `./extract-files.py <dump>` + `./setup-makefiles.py` | ⬜ needs the `tools/extract-utils` package from a synced tree (or a build host) |
| Generate `vendor/xiaomi/sm8750-common` | same, from the common tree | ⬜ |
| Add `BoardConfigVendor.mk` include | already wired in `BoardConfig.mk` | ✅ |

**Acceptance:** `m evolution` gets past vendor makefile resolution; no missing blobs at
`installclean`; `vendor/xiaomi/miro/miro-vendor.mk` generated.

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
- 2026-10-14 — **Phase 2 complete.** Dumped the recovery payload (49 partitions); populated
  `device/xiaomi/miro-kernel/` (kernel `6.6.118-…`, 8 DTBs, dtbo.img, 411+380+96 modules);
  `unpack-kernel-artifacts.sh` rewritten for EROFS/LZ4-cpio/FDT splitting; SPL corrected to
  `2026-08-01` and overridden in the miro BoardConfig; super corrected to 11 GiB; docs and
  AGENTS.md updated; hyperdroid skills installed under `.agents/skills/`.
