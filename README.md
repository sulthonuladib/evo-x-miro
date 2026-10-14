# miro-kernel-extract

Bring-up kit for **Evolution X (Android 17 / `cnb`)** on the **POCO F7 Ultra**
(Redmi K80 Pro), codename **`miro`**, platform **`sun`** (Snapdragon 8 Elite, SM8750).

## Start here

- **New session?** Read [`AGENTS.md`](AGENTS.md) (context + agent roster), then
  [`PLAN.md`](PLAN.md) (phased roadmap → flashable ROM).

## What's here

| Path | What it is |
| --- | --- |
| `AGENTS.md` | Context for a fresh agent: facts, conventions, agent roster |
| `PLAN.md` | Phased plan from scaffolding → flashable, self-updating ROM |
| `docs/evolution-x-miro-bringup.md` | Full research: kernel, ROM codebase, hardware map, OTA, risks |
| `docs/build-cnb.md` | **Step-by-step A17 build runbook** |
| `docs/maintenance.md` | **Keeping in sync with Evolution X + firmware/vendor updates** |
| `manifest/miro.xml` | Local manifest for the Evolution X `cnb` tree |
| `device/xiaomi/miro/` | Device tree scaffold (A17) |
| `device/xiaomi/miro-kernel/` | Prebuilt kernel-artifacts layout + how to populate it |
| `vendor/xiaomi/miro/` | Vendor-blob generation notes |
| `tools/` | Stock ROM → partition images → kernel artifacts |

## Quick facts

- Device: POCO F7 Ultra = Redmi K80 Pro = `miro` (do not confuse with `zorn` = Redmi K80/SM8650).
- Kernel: Linux **6.6.30 GKI** (`android15-6.6`), Xiaomi OSS branch **`bsp-miro-v-oss`**,
  Qualcomm baseline `qcom-LA.VENDOR.14.3.0.r1-14500-r1.0.r1_00042.0`.
- Stock kernel string: `6.6.30-android15-8-gc6f5283046c6-ab12364222-4k`.
- Target: Evolution X branch **`cnb`** = Android 17 (EVO 12.3). SM8750 is already supported
  on A17 by LineageOS 24 and by the `Crisp-los` `cnb` SM8750 common tree, which already
  contains a `miro` code path.
- Start from the existing A17 `sm8750-common` tree + a prebuilt-stock kernel; do **not**
  start from scratch.

## Build in one paragraph

`repo init -u https://github.com/Evolution-X/manifest -b cnb`, add `manifest/miro.xml`,
sync, generate keys, extract the stock recovery ROM with `tools/`, generate the vendor
trees, then `lunch` + `m evolution`. Details in [`docs/build-cnb.md`](docs/build-cnb.md).

> ⚠️ A full A17 build needs ~400 GB free disk and ~64 GB RAM. Do it on a build host, not a laptop.

## Status

Research + scaffolding. Not yet flashed on a device. Needs the stock ROM to populate the
kernel artifacts and vendor blobs.
