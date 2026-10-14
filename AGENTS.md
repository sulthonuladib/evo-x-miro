# AGENTS.md

Context for any agent (or human) starting fresh on this repo. Read this first, then
open the one doc the current task points at.

## What this repo is

A bring-up kit for **Evolution X (Android 17 / `cnb`)** on the **POCO F7 Ultra**
(Redmi K80 Pro), codename **`miro`**. We are *not* building the ROM here — we produce the
device tree, kernel-artifacts tree, vendor-blob generation, and the extraction tooling that
a full Evolution X checkout consumes.

## Orientation

- **`PLAN.md`** — phased roadmap, current status, and the definition of "flashable". Start here for "what do we do next".
- **`docs/evolution-x-miro-bringup.md`** — the research: kernel, ROM codebase, hardware map, sources.
- **`docs/build-cnb.md`** — the build runbook (host setup → `m evolution`).
- **`docs/maintenance.md`** — syncing with Evolution X, firmware/vendor updates, releasing.
- **`manifest/miro.xml`** — local manifest for the `cnb` tree.
- **`device/xiaomi/miro/`**, **`device/xiaomi/miro-kernel/`**, **`vendor/xiaomi/miro/`**, **`tools/`** — the kit itself.

## Hard facts (do not re-derive)

- `miro` = Redmi K80 Pro = POCO F7 Ultra. Platform **`sun`**, SoC **SM8750**.
  (`zorn` = Redmi K80 / SM8650 — a different device.)
- Target branch: Evolution X **`cnb`** = Android 17. Base common tree:
  `Crisp-los/android_device_xiaomi_sm8750-common` `cnb` (already has a `miro` code path).
- Kernel: stock string **`6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k`** (from
  OS3.0.302.0.WOMIDXM; the OS2.0.107.0 dump's `6.6.30-…` is stale), GKI
  `android15-6.6`. Xiaomi OSS branch `bsp-miro-v-oss` is based on 6.6.30.
- Vendor baseline: **Android 16 / HyperOS 3** (`OS3.0.302.0.WOMIDXM`) — the stock ROM at
  `/mnt/games/miro-files/`. (The public `OS2.0.107.0` dump was Android 15; prefer the local ROM.)
- `MIRO_KERNEL_VERSION` and the AVB rollback/security-patch values must be re-derived from that ROM.

## Conventions

- **Never hand-write vendor blobs.** They are generated with `extract_utils`; commit the
  file list and fixups, not the binaries.
- **Super is 11 GiB on this baseline.** The OS3.0.302.0 fastboot GPT sizes `super` at
  `11811160064` / dynamic `11809841488` (the common tree default is correct). The old
  OS2.0.107.0 (Android 15) dump's `9126805504` no longer applies after flashing the
  OS3.0.302.0 fastboot ROM. Verify with `lpdump` on the device.
- **Rollback index moves with firmware.** OS3.0.302.0.WOMIDXM reports SPL **2026-08-01**
  (`1785542400`). `device/xiaomi/miro/BoardConfig.mk` re-states the AVB rollback indexes
  because the common tree still carries `2026-02-01`; bump both together (and bump the
  common tree once forked) on any stock-firmware update.
- **Enforcing SELinux.** The `cnb` tree is enforcing; keep it that way.
- **This machine cannot build A17** (46 GB disk / 31 GB RAM vs ~250 GB / 64 GB). It can run
  the extraction tooling. Builds happen on a host/CI.
- **Keep a single source of truth.** Device facts live in `docs/`; the kit points at them.
  When you learn something new, edit the owning doc, don't duplicate it.

## Agent roster

Dispatch to a specialist when a task matches its column; otherwise stay in the orchestrator.

| Agent | Owns | Load these skills |
| --- | --- | --- |
| **Orchestrator** | Sequencing, plan updates, decisions log | — |
| **Extraction** | Stock ROM → partition images → kernel artifacts; `tools/` | — |
| **Device-tree** | `device/xiaomi/miro/*`, BoardConfig/device.mk, overlays, displayconfig | — |
| **Kernel** | Prebuilt artifacts; later the Kleaf `bsp-miro-v-oss` build | `reverse-engineer-anything` (vendor analysis), `android-profiler` (perf) |
| **HAL bring-up** | Fingerprint/UDFPS, camera, audio, sensors, vibrator, touch | `android-permissions-security` |
| **Firmware/AVB** | `proprietary-firmware.txt`, rollback indexes, firmware-in-OTA | — |
| **QA on device** | Flashing, logcat/dmesg/avc triage, battery/thermal | `android-cli`, `android-profiler`, `diagnosing-bugs` |
| **Release/OTA** | Signing, `miro.json`, changelogs, publishing | — |
| **Docs** | Keep `docs/`, `PLAN.md`, `AGENTS.md` current | `writing-for-agents`, `research` |
| **Review** | Standards + spec review of a change set | `code-review` |

## Status

Phases 0 and 2 are complete; Phase 3 (vendor trees) is in progress: the file list,
extract-utils drivers and fixups are committed, the blob extraction run is pending a synced
`cnb` tree (Phase 1) or a build host. Current phase and next action: see `PLAN.md` →
"Current status".
