# POCO F7 Ultra (`miro`) — Evolution X bring-up research

Notes on the kernel, the Evolution X codebase, hardware enablement, the stock ROM, and
OTA strategy for the POCO F7 Ultra. Every non-obvious claim links to the source that owns it.

> Status: research / planning. Nothing here has been flashed on a device yet.

---

## 0. TL;DR

| Question | Answer |
| --- | --- |
| What device is this? | POCO F7 Ultra = **Redmi K80 Pro**, codename **`miro`**, platform **`sun`**, SoC **Snapdragon 8 Elite (SM8750)** |
| Kernel source | `MiCode/Xiaomi_Kernel_OpenSource`, branch **`bsp-miro-v-oss`**, Linux **6.6.30** GKI, Qualcomm baseline `qcom-LA.VENDOR.14.3.0.r1-14500-r1.0.r1_00042.0` |
| Kernel shape | Android 15/16 GKI (`android15-6.6`), Kleaf/Bazel, target `miro`, variants `consolidate` / `perf` |
| ROM base | Evolution X. Branch **`bka`** = Android 16 (matches the existing LineageOS 23.2 work); branch **`cnb`** = Android 17 (current dev). **Android 17 is feasible** — SM8750 is already supported on A17 by LineageOS 24 and by an Evolution X SM8750 `cnb` tree (see §3.7). |
| Best starting point | **Do not start from scratch.** Fork the Xiaomi SM8750 `lineage-23.2` bring-up (`sm8750-common` + a device tree + prebuilt kernel). `miro` is explicitly listed as a target for that common tree. |
| Biggest early risk | AVB **rollback index vs. stock security patch level**, and the fact that `miro` has a **dedicated `recovery` partition** (not `recovery-as-boot`). |
| OTA | A/B + VABC `payload.bin`. Unofficial → custom OTA JSON served from Cloudflare R2 / GitHub + a `strings.xml` overlay wired to Evolution X's `Updater`. Official → apply for maintainership. |
| Stock ROM | Keep **both** the fastboot ROM (firmware / bootloader / modem) and the recovery ROM (vendor blobs + kernel modules). You need blobs, firmware and `vendor_dlkm`/`system_dlkm` modules. |

---

## 1. Device identity

`miro` is the Redmi K80 Pro (China) sold globally as the **POCO F7 Ultra**. The Xiaomi OSS
kernel commit on `bsp-miro-v-oss` says so directly:

> `Kernel: Xiaomi kernel changes for REDMI K80 PRO Android V`
> — <https://github.com/MiCode/Xiaomi_Kernel_OpenSource/commit/cbcc4fdcaee0f6001a1db89c998894a9ff752387>

Do **not** confuse it with its siblings:

| Device | Codename | SoC / platform | Xiaomi OSS branch |
| --- | --- | --- | --- |
| POCO F7 Ultra / Redmi K80 **Pro** | **`miro`** | SM8750 (`sun`) | `bsp-miro-v-oss` |
| Redmi K80 (non-Pro) | `zorn` | SM8650 (`pineapple`) | `bsp-zorn-v-oss` |

`bsp-zorn-v-oss`'s commit says "REDMI K80 … based on qcom-LA.VENDOR.14.3.0…" and its
`build.config.msm.zorn` inherits `build.config.msm.pineapple` — i.e. it is a different SoC
entirely. `miro` inherits `build.config.msm.sun` (SM8750). Source:
<https://raw.githubusercontent.com/MiCode/Xiaomi_Kernel_OpenSource/bsp-zorn-v-oss/build.config.msm.zorn>.

### Official hardware spec (from Xiaomi's spec page)

Source: <https://www.mi.com/global/product/poco-f7-ultra/specs/>

- **SoC**: Snapdragon 8 Elite, 3 nm, 2× Oryon prime @ 4.32 GHz + 6× @ 3.53 GHz, Adreno GPU, Hexagon NPU.
- **RAM/storage**: 12/16 GB LPDDR5X, 256/512 GB UFS 4.1.
- **Display**: 6.67" WQHD+ (3200×1440) AMOLED, up to 120 Hz, 3200 nits peak, 3840 Hz PWM,
  12-bit, **HDR10+ / Dolby Vision**.
- **Cameras**: 50 MP main (Light Fusion 800, OIS, f/1.6) + 50 MP floating telephoto (60 mm, OIS)
  + 32 MP ultrawide; 32 MP front; 8K24 / 4K60 video.
- **Battery**: 5300 mAh, **120 W wired + 50 W wireless** HyperCharge.
- **Security**: **ultrasonic in-display fingerprint**.
- **Connectivity**: Wi-Fi 7, Bluetooth 6.0, NFC, dual-SIM 5G, **IR blaster**.
- **Audio**: stereo speakers, 3-mic array, Hi-Res / Dolby Atmos.
- Ships with HyperOS 2 (Android 15 base).

---

## 2. Kernel research

### 2.1 Source and version

- Repo: <https://github.com/MiCode/Xiaomi_Kernel_OpenSource>
- Branch: **`bsp-miro-v-oss`**
- HEAD: `cbcc4fdcaee0f6001a1db89c998894a9ff752387` (authored 2025-01-23 by `chenyujia3@xiaomi.com`)
- `Makefile`: `VERSION = 6`, `PATCHLEVEL = 6`, `SUBLEVEL = 30`
- Qualcomm baseline: `qcom-LA.VENDOR.14.3.0.r1-14500-r1.0.r1_00042.0` (Lahaina/Vendor 14.3, i.e. the
  Qualcomm Android 15/16 BSP for `sun`).

This is a **GKI** kernel. The stock device runs the merged string
**`6.6.30-android15-8-gc6f5283046c6-ab12364222-4k`** (read out of the dump; see §5), and the
Evolution X manifest ships a matching `kernel-6.6` platform snippet pinned to
`android15-6.6-2026-07`:
<https://raw.githubusercontent.com/Evolution-X/manifest/cnb/snippets/kernel-6.6.xml>.

### 2.2 Source layout and build system

Qualcomm's modern 6.6 kernel is a **Kleaf/Bazel** platform. The Xiaomi mirror is flattened
(the `msm-kernel` contents live at the repo root) and contains the platform build logic:

- `BUILD.bazel`, `build_with_bazel.py`, `abi.bzl`, `sun.bzl`, `miro.bzl`,
  `xiaomi_sm8750_common.bzl`, `msm_platforms.bzl`, `target_variants.bzl`
- `build.config.msm.miro`, `build.config.msm.sun`, `build.config.msm.common`
- `modules.list.msm.miro`, `modules.vendor_blocklist.msm.miro`,
  `modules.systemdlkm_blocklist.msm.miro`
- `arch/arm64/configs/vendor/miro_perf.config`, `…/miro_consolidate.config`
- `arch/arm64/configs/vendor/sun_perf.config`, `…/sun_consolidate.config`

`build.config.msm.miro` (verbatim):

```
. ${ROOT_DIR}/msm-kernel/build.config.msm.sun
```

`build.config.msm.sun` sets the important knobs:

```
MSM_ARCH=sun
VARIANTS=(consolidate perf)
[ -z "${VARIANT}" ] && VARIANT=consolidate
BOOT_IMAGE_HEADER_VERSION=4
BASE_ADDRESS=0x80000000
PAGE_SIZE=4096
BUILD_VENDOR_DLKM=1
PREPARE_SYSTEM_DLKM=1
BUILD_INIT_BOOT_IMG=1
SUPER_IMAGE_SIZE=0x10000000
DT_OVERLAY_SUPPORT=1
KERNEL_VENDOR_CMDLINE+=' bootconfig '
```

`miro.bzl` defines target `miro` and the Xiaomi in-tree modules:

| Module | Purpose |
| --- | --- |
| `drivers/input/fingerprint/mi_fp/mi_fp.ko` | Xiaomi fingerprint (UDFPS) |
| `drivers/misc/perf_helper/perf_helper.ko` | Xiaomi perf helper |
| `drivers/gpio/gpio-mi-t1.ko` | Xiaomi T1 companion chip GPIO |
| `drivers/power/supply/mca/…/sc96281_comp.ko` | SC96281 wireless-charging IC |
| `drivers/media/rc/ir-spi.ko` | **IR blaster** (over SPI) |
| `drivers/mihw/powersave/powersave.ko`, `…/unionpower/unionpower.ko` | Xiaomi power/thermal |
| `drivers/leds/leds-aw21024.ko` | AW21024 LED/haptics driver |
| `drivers/mtd/*` (`mtd`, `mtdblock`, `mtdoops`, `block2mtd`, `ofpart`, `chipreg`) | MTD / boot logs |

`miro_perf.config` / `miro_consolidate.config` confirm the same set
(`CONFIG_INPUT_FINGERPRINT=y`, `CONFIG_FINGERPRINT_MI_FP=m`, `CONFIG_IR_SPI=m`,
`CONFIG_MCA_EXTERNAL_WIRELESS_SC96281=m`, `CONFIG_LEDS_AW21024=m`, `CONFIG_MI_T1_CHIP=m`,
`CONFIG_LIRC=y`, `CONFIG_RC_CORE=y`).

Takeaway: **the OSS kernel already contains the Xiaomi-specific drivers for the marquee
hardware** (ultrasonic fingerprint, IR, wireless charging, haptics LED, power/thermal).
What is *not* in the kernel is the userspace vendor HALs/blobs — those come from the stock ROM.

### 2.3 Boot image format

From the `miro` dump's generated `BoardConfig.mk` and the stock `fstab.qcom`:

- Android boot image **header version 4**, page size **4096**, base **0x00000000**, `Image`.
- `BOARD_INCLUDE_DTB_IN_BOOTIMG := true`, `BOARD_KERNEL_SEPARATED_DTBO := true`.
- A/B device with **separate `init_boot`**, **`vendor_boot`**, **`dtbo`**, and — importantly —
  a **real `recovery` partition** (see §3.4).
- Bootconfig is used (`bootconfig` on the vendor cmdline).

### 2.4 Two viable kernel strategies

**A. Prebuilt-from-stock (fastest path to a booting ROM).**
Mirror the Xiaomi 15 Pro kernel-artifacts repo layout
(<https://github.com/xiaomi-haotian-devs/android_device_xiaomi_haotian-kernel>) and populate it
from the `miro` dump:

```
device/xiaomi/miro-kernel/
├── kernel                     # extracted Image (from boot.img / vendor_boot)
├── dtb/*.dtb                  # from dtbo.img / vendor_boot DTB
├── dtbo.img
├── kernel-headers/            # for TARGET_KERNEL_SOURCE / out-of-tree modules
├── prebuilt_kernel_headers.tar.gz
├── vendor_ramdisk/*.ko        # modules loaded in recovery/vendor ramdisk
├── vendor_dlkm/*.ko
└── system_dlkm/6.6.30-android15-8-gc6f5283046c6-ab12364222-4k/…
```

This is exactly how the haotian tree installs it (`BoardConfig.mk`):
`TARGET_NO_KERNEL_OVERRIDE`, `TARGET_KERNEL_SOURCE := $(KERNEL_PATH)/kernel-headers`,
`TARGET_PREBUILT_KERNEL_HEADERS`, `BOARD_VENDOR_RAMDISK_KERNEL_MODULES`,
`BOARD_VENDOR_KERNEL_MODULES`, `BOARD_PREBUILT_DTBOIMAGE`, `BOARD_PREBUILT_DTBIMAGE_DIR`.

**B. Build from source (higher effort, gives you kernel control / KernelSU / upstream).**
Because the Xiaomi mirror is flattened and sources `${ROOT_DIR}/msm-kernel/...`, you generally
assemble a Qualcomm `kernel_platform`-shaped tree:

```
kernel_platform/
├── common/            # ACK android15-6.6 (Google)
├── msm-kernel/        # this Xiaomi branch, placed as msm-kernel/
├── msm-kernel/devicetrees  # sun device trees
├── build/             # kleaf + build.sh
└── prebuilts/
```

The alternative used by the `xiaomi-dada` project is to split it into three repos and build all
of it from source:
`android_kernel_xiaomi_sm8750`, `android_kernel_xiaomi_sm8750-devicetrees`,
`android_kernel_qcom_sm8750-modules` (see §3.3).

**Recommendation:** start with strategy **A** to get a booting, daily-usable ROM quickly, then
switch to **B** once the device tree is stable. This matches what the existing `miro` maintainer
reports on XDA: his LineageOS 23.2 bring-up uses "a hardware baseline implementation that
bypasses broken Xiaomi source code" and a prebuilt kernel, rather than building the OSS tree
as-is (<https://xdaforums.com/t/lineageos-23-2-android-16-for-poco-f7-ultra-miro.4792277/>).
Expect to spend real time making the OSS kernel build cleanly if you choose strategy B.

---

## 3. ROM codebase: Evolution X

### 3.1 Branches

Evolution X is LineageOS-derived. Its manifest is
<https://github.com/Evolution-X/manifest>; relevant branches:

| Branch | Android | AOSP tag / LOS | Notes |
| --- | --- | --- | --- |
| `vic` | 15 | | documented in the OTA guide |
| `bka` | 16 | | matches the existing `miro` LineageOS 23.2 work |
| `cnb` | 17 | `android-17.0.0_r1`, `lineage-24.0`, EVO `12.3` | current default branch |

Evidence: `cnb/default.xml` pins `remote aosp … revision="refs/tags/android-17.0.0_r1"` and
`<default revision="refs/heads/lineage-24.0">`, and
`vendor_evolution/config/version.mk` sets `PRODUCT_VERSION_MAJOR = 17` / `EVO_VERSION_BASE := 12.3`.

For a first bring-up I would target **`bka` (Android 16)** so the device tree can follow the
existing SM8750 `lineage-23.2` trees, then rebase to `cnb` later.

### 3.2 Build setup (from the official wiki)

Source: <https://wiki.evolution-x.org/setting-up-env>

```bash
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf \
  lib32readline-dev lib32z1-dev libdw-dev libelf-dev lz4 libsdl1.2-dev libssl-dev \
  libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip \
  zlib1g-dev python-is-python3

mkdir -p ~/evo && cd ~/evo
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
. build/envsetup.sh
```

Minimum build box per the wiki: **12 cores, 64 GB RAM**. Generate signing keys (unofficial):

```bash
git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template \
  vendor/evolution-priv/keys
cd vendor/evolution-priv/keys && ./keys.sh
```

Lunch and build (Android 16 form):

```bash
lunch lineage_miro-<release>-userdebug     # release token documented on the wiki
m evolution
```

### 3.3 The dependency map you should copy

The cleanest, most current SM8750 dependency list is the Xiaomi 15 (`dada`) local manifest:
<https://raw.githubusercontent.com/xiaomi-dada/local_manifests/main/dada.xml>. It shows exactly
which trees an SM8750 device needs:

- **Device**: `device/xiaomi/<dev>`, `device/xiaomi/<dev>-kernel`, `device/xiaomi/sm8750-common`
- **Vendor blobs**: `vendor/xiaomi/<dev>`, `vendor/xiaomi/sm8750-common`,
  `vendor/xiaomi/<dev>-firmware`
- **Kernel**: `kernel/xiaomi/sm8750`, `kernel/xiaomi/sm8750-devicetrees`,
  `kernel/xiaomi/sm8750-modules-qcom`
- **AudioReach**: `vendor/qcom/opensource/agm`,
  `vendor/qcom/opensource/audioreach-graphservices` (built from source, `fix/vendor-abi`)
- **Xiaomi framework**: `hardware/xiaomi` (`LineageOS/android_hardware_xiaomi`)
- **Lineage health HAL**: fork of `hardware/lineage/interfaces` for charging control
- Deliberately **not** overridden upstream: `device/lineage/sepolicy`,
  `vendor/qcom/opensource/vibrator`, `hardware/dolby`

Public SM8750 device trees you can base `miro` on:

- <https://github.com/xiaomi-haotian-devs/android_device_xiaomi_sm8750-common> (branch `lineage-23.2`)
  — its README explicitly lists **"Redmi K80 Pro / POCO F7 Ultra (Miro)"** as a target device.
- <https://github.com/Crisp-los/android_device_xiaomi_sm8750-common>
- Recovery trees for `miro` already exist and are useful for partition/mount reference:
  <https://github.com/lxsc-zk/android_device_xiaomi_miro_ofox>,
  <https://github.com/twrpdtgen/android_device_xiaomi_miro>,
  <https://github.com/AviderMin/ofrp_device_xiaomi_miro>
- Existing (README-only) kernels/build notes:
  <https://github.com/Advancefeescam/android_device_xiaomi_miro>,
  <https://github.com/Advancefeescam/android_kernel_poco_f7_ultra> (branch `bsp-miro-v-oss`)

### 3.4 `miro`-specific BoardConfig facts (from a real dump)

The dump at <https://github.com/Jiovanni-dump/poco_miro_dump> is generated from
`miro:15/OS2.0.107.0.VOMMIXM:user`. Its `aosp-device-tree/BoardConfig.mk` gives the values that
**must not be copied blindly from haotian**, because the SM8750 common tree targets a different
super size:

| Setting | `miro` (real) | Xiaomi 15 Pro `sm8750-common` |
| --- | --- | --- |
| `BOARD_SUPER_PARTITION_SIZE` | `9126805504` (8.5 GiB) | `11811160064` (11 GiB) |
| dynamic group name | `xiaomi_dynamic_partitions` | `qti_dynamic_partitions` |
| dynamic size | `9122611200` | `11809841488` |
| dynamic list | `vendor_dlkm system product system_ext system_dlkm vendor odm` | `… odm` (no `mi_ext`) |
| `BOARD_*IMAGE_PARTITION_SIZE` | boot `100663296`, dtbo `18874368`, recovery `104857600`, init_boot `8388608`, vendor_boot `100663296` | dtbo `25165824` |

`miro` also carries the Xiaomi logical `mi_ext` partition (mounted via overlayfs per the stock
`fstab.qcom`), and a real `/dev/block/by-name/recovery` node. The OrangeFox tree for `miro`
notes the same thing: *"K80 Pro has an independent recovery, so recovery-as-boot is disabled."*
The generic dump tree's `BOARD_USES_RECOVERY_AS_BOOT := true` is therefore a leftover and should
**not** be trusted — prefer `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` and a normal
recovery image (as in the haotian tree).

`AB_OTA_PARTITIONS` for `miro`: `vendor_dlkm dtbo init_boot system recovery product system_ext
system_dlkm vendor odm boot vendor_boot`.

### 3.5 `evolution.dependencies` (official) vs. local manifest (unofficial)

- **Unofficial**: put a `<device>.xml` under `.repo/local_manifests/` and sync.
  (<https://wiki.evolution-x.org/lunch>)
- **Official**: replace `lineage.dependencies` with `evolution.dependencies`, matching the
  Evolution X device-org naming (`device_xiaomi_miro` → `device/xiaomi/miro`, etc.).

### 3.6 Evolution X build flags relevant to `miro`

From <https://wiki.evolution-x.org/build_flags>:

| Flag | Value | Why |
| --- | --- | --- |
| `TARGET_HAS_UDFPS` | `true` | ultrasonic in-display fingerprint |
| `TARGET_SUPPORT_BOOT_ANIMATIONS` | `true` | boot animation support |
| `TARGET_INCLUDE_GRAMOPHONE` / `TARGET_INCLUDE_VIPERFX` | optional | extra audio apps |
| `WITH_GMS` | `true` | "native"/Pixel-like experience, matching official POCO builds |
| `EVO_BUILD_TYPE` | `Unofficial` (export) | until official |

### 3.7 Android 17 (`cnb`) — is it possible? Yes, and it is the current dev branch

Short answer: **yes.** The whole stack already supports SM8750 on Android 17, and an A17
Evolution X SM8750 common tree even has `miro`-specific code. Details:

- **AOSP 17 exists.** The `cnb` manifest pins `remote aosp … revision="refs/tags/android-17.0.0_r1"`
  and `<default revision="refs/heads/lineage-24.0">`; `vendor_evolution/config/version.mk` reports
  `PRODUCT_VERSION_MAJOR = 17`, `EVO_VERSION_BASE := 12.3`. So Evolution X `cnb` = Android 17.
- **LineageOS 24 supports SM8750.**
  `https://github.com/LineageOS/android_device_oneplus_sm8750-common` has a `lineage-24.0` branch
  (confirmed via `git ls-remote --heads`), and its kernel
  (`LineageOS/android_kernel_oneplus_sm8750`, branch `lineage-24.0`) is **Linux 6.6.144**.
  So Android 17 + GKI 6.6 on `sun`/SM8750 is a supported combination.
- **Evolution X A17 SM8750 common tree already exists:**
  `https://github.com/Crisp-los/android_device_xiaomi_sm8750-common` on branch **`cnb`**.
  It is a full A17 common tree (AIDL fingerprint HAL, `udfps/`, `sensors/`, VINTF manifests,
  sepolicy, overlays, `hardware/xiaomi` namespace) — the direct descendant of the `lineage-23.2`
  tree from §3.3.
- **It already knows about `miro`.** `common.mk` line 274:

  ```make
  ifneq ($(filter miro piano,$(TARGET_DEVICE)),)
  # PowerShare
  $(call soong_config_set,lineage_powershare,powershare_path,/sys/class/qcom-battery/reverse_chg_mode)
  PRODUCT_PACKAGES += vendor.lineage.powershare-service.default
  endif
  ```

  i.e. the A17 common tree has a `miro`/`piano` code path (reverse wireless charging), so the
  platform is already being developed with this device in mind. (`piano` is another Xiaomi SM8750
  device with its own kernel branch `piano-w-oss`.)
- **Kernel branch for A17 is still 6.6.** The A17 `cnb` manifest ships
  `snippets/kernel-6.6.xml` pinned to `android15-6.6-2026-07` (plus `kernel-6.12.xml` →
  `android16-6.12-2026-06` and `kernel-6.18.xml` → `android17-6.18-2026-06`). SM8750 uses the 6.6
  path, i.e. the **`android15-6.6` ACK branch** — the same branch Xiaomi's `bsp-miro-v-oss` is
  based on. No 6.12/6.18 migration is required.
- **The vendor baseline is unchanged.** The `cnb` common tree keeps
  `BOARD_SHIPPING_API_LEVEL := 202404` and `PRODUCT_SHIPPING_API_LEVEL := 35` — the Android 15
  vendor baseline — which is exactly what the `miro` stock firmware provides. So the stock vendor
  blobs are expected to work on A17.

What actually changes for A17 (from the `cnb` tree):

- `androidboot.selinux=permissive` is **gone** from `BOARD_BOOTCONFIG` (the A16 haotian tree still
  had it). A17 expects **enforcing** SELinux — do not reintroduce permissive.
- `BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true` is kept, matching `miro`'s dedicated
  recovery partition.
- VINTF/common.mk gained A17-era packages (`libaudiocorehal.default`, a trimmed `hardware/xiaomi`
  namespace, `xiaomi-telephony-stub`, PowerShare service) — copy the `cnb` tree rather than hand-
  porting the A16 one.

Practical recommendation:

- **Target `cnb` (A17) if you want the latest**, but treat the `Crisp-los` `cnb` common tree as the
  compatibility oracle and only add a `device/xiaomi/miro` + `vendor/xiaomi/miro` on top of it.
- **Target `bka` (A16) if you want the lowest-risk first boot**, because the only public `miro`
  work (LineageOS 23.2, maintained by `Advancefeescam`/getAOSP) is A16-based and already boots.
- You can also build A16 first, then rebase the same device tree onto `cnb` once it boots — the
  BoardConfig deltas between the two common trees are small (per the diff above).

Nothing about A17 is fundamentally blocked for `miro`. You would be **the first to build `miro` on
A17 publicly**, but every dependency (AOSP tag, LOS 24 SM8750 tree, EvoX `cnb` SM8750 tree, GKI
6.6, Android 15 vendor baseline) is already in place.

---

## 4. Hardware feature map: what enables what

Derived from the dump's `proprietary-files.txt`, `odm.prop` / `vendor.prop` / `product.prop`, and
the kernel fragments. "ROM work" is the part a porter must actually wire up.

| Feature | Kernel driver | Vendor HAL / blob (stock) | ROM work |
| --- | --- | --- | --- |
| **Ultrasonic UDFPS** | `mi_fp.ko`, `CONFIG_INPUT_FINGERPRINT=y` | `fingerprint.goodix_us.so`, `libgf_hal.so`, `vendor.xiaomi.hardware.fingerprintextension*` | Port the AIDL fingerprint HAL + UDFPS handler from `sm8750-common/fingerprint`; set `TARGET_HAS_UDFPS := true` |
| **IR blaster** | `ir-spi.ko`, `CONFIG_RC_CORE=y` | `consumerir.qcom.so`, `xiaomi_ir_test` | Ensure `consumerir` HAL is packaged; IR app (e.g. AOSP IR / third-party) |
| **120 Hz WQHD+ / LTPO** | display (QTI) | `vendor.qti.hardware.display.*`, `com.xiaomi.ugd` GPU driver | Keep `TARGET_SCREEN_DENSITY := 600`; handle `ro.gfx.driver.0=com.xiaomi.ugd`; refresh-rate switching |
| **Dolby Vision** | — | display HWC | `ro.surface_flinger.has_HDR_display=true`, `debug.config.media.video.dolby_vision_suports=true`; needs HWC + framework support |
| **Ultra HDR / Adaptive HDR** | — | — | `persist.sys.support_ultra_hdr`, `persist.sys.adaptive_hdr_supported` |
| **Dolby Atmos / spatial audio** | AudioReach | `ozoaudio` libs, `misoundsa*` configs, `ro.vendor.audio.dolby.dax.*` | Build AudioReach (`agm` + `audioreach-graphservices`); note `hardware/dolby` is dropped by some trees for licensing |
| **Cameras (50/50/32 MP)** | QTI CAMSS | `camera.qcom.sm8750.so`, `vendor.qti.camera.provider-service_64`, Xiaomi `dynamiccameraserver`, `libportrait_repair_qnn.so` | Camera provider works from blobs; a Xiaomi camera app is needed for full feature parity (CameraMind, live photo) |
| **QTI haptics / RichTap** | `leds-aw21024.ko` | `ro.odm.mm.vibrator.sys_path=/sys/class/qcom-haptics` | Decide QTI vibrator HAL vs. AOSP vibrator; the `dada` manifest deliberately drops the QTI vibrator HAL, verify per-device |
| **Wireless charging 50 W** | `sc96281_comp.ko` | power-supply HAL | Keep Xiaomi power-supply HAL; charging UI |
| **120 W wired charging** | QTI | `persist.vendor.accelerate.charge` | Health HAL + charging control (Lineage health interfaces fork) |
| **Wi-Fi 7 / BT 6.0** | `qcacld` / WLAN | `qcwcn` blobs | Use the common tree's WLAN/BT config verbatim |
| **NFC** | — | `ro.nfc.port=I2C`, NXP blobs | Package NFC HAL + firmware |
| **5G / VoLTE / VoWiFi** | — | QTI RIL + modem | `ENABLE_VENDOR_RIL_SERVICE := true`; verify IMS configs |
| **GPU (Adreno)** | — | `ro.gfx.driver.0=com.xiaomi.ugd` | Xiaomi's updatable GPU driver; may need to be removed/overridden if it misbehaves on AOSP |

**Practical rule:** the kernel side is mostly already solved by `bsp-miro-v-oss`. Feature work is
almost entirely **userspace**: extracting the right blobs, wiring VINTF manifests, sepolicy, and
the AIDL HAL wrappers (especially the fingerprint/UDFPS one, which is why `sm8750-common` ships a
hand-written `fingerprint/` HAL).

---

## 5. What to extract from the stock ROM

You offered both fastboot and recovery ROMs — keep **both**, they serve different purposes:

| Artifact | Fastboot ROM | Recovery ROM (`payload.bin`) |
| --- | --- | --- |
| Bootloader (`xbl`, `abl`, `tz`, `hyp`, `keymaster`, …) | ✅ | ✗ |
| Modem / DSP / BT / ADSP firmware | ✅ | partial |
| `boot` / `init_boot` / `vendor_boot` / `dtbo` | ✅ | ✅ |
| `vendor` / `odm` / `system_ext` / `product` blobs | ✅ | ✅ |
| `vendor_dlkm` / `system_dlkm` kernel modules | ✅ | ✅ |

The already-published dump you can diff against is
<https://github.com/Jiovanni-dump/poco_miro_dump> (POCO F7 Ultra, `OS2.0.107.0.VOMMIXM`) and
<https://github.com/RandomPush/redmi_miro_dump> (Redmi K80 Pro, `OS2.0.11.0.VOMCNXM`). Both
contain `vendor/`, `odm/`, `system_ext/`, `product/`, `system_dlkm/`, `vendor_dlkm/`,
`boot.img`, `init_boot.img`, `vendor_boot.img`, `dtbo.img`, and an
`aosp-device-tree/` with `proprietary-files.txt` (4,768 lines) plus `extract-files.sh` and
`setup-makefiles.sh`.

Observed identity for the dump:

- build: `qti/missi/missi:15/AQ3A.240829.003/OS2.0.107.0.VOMMIXM:user/release-keys`
- kernel: `6.6.30-android15-8-gc6f5283046c6-ab12364222-4k` (`CONFIG_LOCALVERSION="-4k"`)
- `board-info.txt`: `version-trustzone=TZ.XF.5.29-00074.1-PAKALA-1.84491.8`,
  `version-vendor=1743514669`

Workflow to produce `vendor/xiaomi/miro`:

1. Run `payload_dumper` (recovery ROM) **or** use the fastboot images to get the partition images.
2. Use the generated `extract-files.py` / `proprietary-files.txt` to build a vendor tree
   (`vendor/xiaomi/miro` + `vendor/xiaomi/sm8750-common`).
3. Copy `vendor_dlkm/` and `system_dlkm/` module trees into the kernel-artifacts repo.
4. Build a `vendor/xiaomi/miro-firmware` blob set from the fastboot ROM if you want
   firmware-updating OTAs.

---

## 6. OTA and updates

### 6.1 Mechanics

The build is A/B with **virtual A/B compression**:
`common.mk` inherits `virtual_ab_ota/vabc_features.mk` and sets
`PRODUCT_VIRTUAL_AB_COMPRESSION_METHOD := lz4`. The build emits an OTA `payload.bin`, and
Evolution X's `packages/apps/Updater` checks a JSON endpoint.

### 6.2 Unofficial OTA (do this first)

From <https://wiki.evolution-x.org/custom-ota/setting-up-custom-ota> and
<https://wiki.evolution-x.org/custom-ota/cloudflare-ota>:

1. Create an overlay in the device tree:

   ```
   overlay-evolution/Updater/res/values/strings.xml
   ```

   ```xml
   <resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
     <string name="updater_server_url" translatable="false">https://raw.githubusercontent.com/<user>/OTA/<branch>/builds/miro.json</string>
     <string name="menu_changelog_url" translatable="false">https://raw.githubusercontent.com/<user>/OTA/<branch>/changelogs/<xliff:g id="device_name">%1$s</xliff:g>.txt</string>
   </resources>
   ```

2. Copy `out/target/product/miro/miro.json` into the OTA repo's `builds/`, upload the zip
   (Cloudflare R2 via `rclone`, or SourceForge / GitHub Releases), and fix the `download` URL,
   `md5`, `sha256`, `size`, `version`, `buildtype` fields.
3. Add `changelogs/miro.txt`.
4. Sign the build with your own keys (`vendor/evolution-priv/keys`). **Back the keys up** — losing
   them means users cannot dirty-flash future builds and Play Integrity breaks.

### 6.3 Official OTA

Apply for maintainership via the Evolution X Discord (`@a7e28`, `@lorditachi_w_`):
<https://wiki.evolution-x.org/apply-for-maintainership>.
Requirements: own the device, medium git skill, a **stable unofficial build first**, a public
device tree, and an `evolution.dependencies` file. Blind builds are explicitly rejected.

### 6.4 The rollback-index / security-patch trap

The haotian `BoardConfigCommon.mk` documents the key gotcha:

```
XIAOMI_SM8750_SECURITY_PATCH := 2026-02-01
XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP := 1769904000
BOARD_AVB_BOOT_ROLLBACK_INDEX := $(…_TIMESTAMP)   # location 3
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := $(…_TIMESTAMP) # location 1
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(…_TIMESTAMP) # location 2
```

> Keep AVB rollback indexes at or above the stock firmware's SPL, or the bootloader can reject a
> freshly flashed inactive slot before Android starts.

For `miro` you must read the **currently installed stock firmware's** SPL and set the rollback
indexes at or above it. The old dump reports `VENDOR_SECURITY_PATCH := 2025-03-01`, which is a
stale baseline — do not ship that.

### 6.5 Play Integrity

Evolution X ships `packages/apps/Pif` and `vendor_certification`, but the wiki is explicit that
the build must be signed with proper keys or it cannot pass `MEETS_BASIC_INTEGRITY` /
`MEETS_DEVICE_INTEGRITY`. Custom self-signed ROMs may still need a PlayIntegrityFix module. This
is the main tension with "native experience + banking apps".

---

## 7. Suggested milestone plan

1. **Dump & diff** — download both stock ROMs; reconcile partition layout and firmware versions.
2. **Boot a stock-derived tree** — fork `xiaomi-haotian-devs/android_device_xiaomi_sm8750-common`
   and the `haotian` device tree, rename to `miro`, fix the super size and rollback indexes, use
   the prebuilt-stock kernel artifacts. Goal: LineageOS 23.2 boots.
3. **Enable radios & display** — RIL/IMS, WLAN/BT/NFC, camera provider, sensors, audio (AudioReach).
4. **Fingerprint/UDFPS** — port the AIDL `fingerprint/` HAL from `sm8750-common`; verify
   enrollment/unlock, fOD dim layer, and `TARGET_HAS_UDFPS`.
5. **Marquee hardware** — IR blaster, wireless charging, Dolby Vision/Atmos, haptics.
6. **Evolution X** — add the `bka` local manifest, device overlays, Evolver defaults, and
   `m evolution`.
7. **OTA** — sign, set up the custom OTA JSON on R2, verify an A/B update end-to-end.
8. **Kernel from source (optional)** — move to the Kleaf build for KernelSU/upstream control.
9. **Apply for official maintainership** once the unofficial build is a stable daily driver.

---

## 8. Risks and gotchas

- **Anti-rollback / AVB**: wrong rollback index = brick-or-refuse-to-boot on the inactive slot.
  This is the single most dangerous setting; get the stock SPL right.
- **`BOARD_SUPER_PARTITION_SIZE`**: must be `miro`'s (8.5 GiB), not haotian's (11 GiB), or the
  build will not produce a flashable super / OTA.
- **Dedicated `recovery` partition**: do not use `recovery-as-boot`; the OrangeFox tree and stock
  fstab both confirm a real recovery partition.
- **`androidboot.selinux=permissive`** appears in the haotian bootconfig. Shipping permissive
  SELinux is a security regression and will fail Play Integrity/CTS-grade checks — treat it as a
  bring-up-only workaround.
- **`ro.gfx.driver.0=com.xiaomi.ugd`**: Xiaomi ships its own updatable GPU driver; AOSP expects
  this property to name a whitelisted driver. Expect to iterate.
- **Licensing**: Dolby (Vision/Atmos), Leica-branded audio (`…camera.leamic…`), and Xiaomi camera
  blobs are not redistributable in the general case. Some trees drop `hardware/dolby` entirely
  for exactly this reason.
- **Bootloader unlock / warranty / region**: unlocking triggers data wipe and may affect banking
  apps and warranty; Chinese (K80 Pro) and global (POCO F7 Ultra) firmwares differ — flash the
  matching region firmware to avoid modem/IMEI issues.
- **Kernel build ABI**: GKI requires the vendor modules' `KMI` to match the `system_dlkm`
  modules. Mixing modules built against a different ACK tag will fail to load.

---

## 9. Source index

**Kernel**
- Xiaomi OSS: <https://github.com/MiCode/Xiaomi_Kernel_OpenSource> branch `bsp-miro-v-oss`
- `build.config.msm.miro` / `build.config.msm.sun`, `miro.bzl`, `xiaomi_sm8750_common.bzl`,
  `arch/arm64/configs/vendor/miro_{perf,consolidate}.config`
- Mirror: <https://github.com/android-kernels/xiaomi-bsp-miro-v-oss>
- KernelSU forks: <https://github.com/sad25kag/GKI-kernelSU_xiaomi_miro>,
  <https://github.com/xiaosu2334/xiaomi_miro_GKI-kernelSU>
- Maintainer fork: <https://github.com/Advancefeescam/android_kernel_poco_f7_ultra>

**Evolution X**
- Manifest: <https://github.com/Evolution-X/manifest>
- Wiki: <https://wiki.evolution-x.org> (env, lunch, build flags, custom OTA, maintainership)
- Updater: <https://github.com/Evolution-X/packages_apps_Updater>
- Keys: <https://github.com/Evolution-X/vendor_evolution-priv_keys-template>
- Kernel snippet: `snippets/kernel-6.6.xml` (`android15-6.6-2026-07`)

**Device bring-up references**
- SM8750 common: <https://github.com/xiaomi-haotian-devs/android_device_xiaomi_sm8750-common>
- Xiaomi 15 Pro: <https://github.com/xiaomi-haotian-devs/android_device_xiaomi_haotian>
  (+ `-kernel`, `proprietary_vendor_*`, `android_hardware_xiaomi`)
- Xiaomi 15 dependency map: <https://github.com/xiaomi-dada/local_manifests>
- `miro` recovery trees: <https://github.com/lxsc-zk/android_device_xiaomi_miro_ofox>,
  <https://github.com/twrpdtgen/android_device_xiaomi_miro>
- `miro` dumps: <https://github.com/Jiovanni-dump/poco_miro_dump>,
  <https://github.com/RandomPush/redmi_miro_dump>
- XDA bring-up thread: <https://xdaforums.com/t/lineageos-23-2-android-16-for-poco-f7-ultra-miro.4792277/>

**Hardware**
- POCO F7 Ultra spec sheet: <https://www.mi.com/global/product/poco-f7-ultra/specs/>
