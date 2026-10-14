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
- Kernel: stock string **`6.6.30-android15-8-gc6f5283046c6-ab12364222-4k`**, GKI
  `android15-6.6`. Xiaomi OSS branch `bsp-miro-v-oss`.
- Vendor baseline: **Android 16 / HyperOS 3** (`OS3.0.302.0.WOMIDXM`) — the stock ROM at
  `/mnt/games/miro-files/`. (The public `OS2.0.107.0` dump was Android 15; prefer the local ROM.)
- `MIRO_KERNEL_VERSION` and the AVB rollback/security-patch values must be re-derived from that ROM.

## Conventions

- **Never hand-write vendor blobs.** They are generated with `extract_utils`; commit the
  file list and fixups, not the binaries.
- **Do not copy the haotian super size.** `miro`'s physical super is
  `9126805504` / dynamic `9122611200`; the common tree defaults to the Xiaomi 15 Pro's
  11 GiB. Verify with `lpdump` before flashing.
- **Rollback index moves with firmware.** Any stock-firmware bump must also bump
  `XIAOMI_SM8750_SECURITY_PATCH` in `device/xiaomi/sm8750-common/BoardConfigCommon.mk`.
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

Research + scaffolding complete. Blocked on the **stock ROM** and a **build host**.
Current phase and next action: see `PLAN.md` → "Current status".
