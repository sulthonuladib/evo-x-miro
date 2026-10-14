# Building Evolution X (Android 17 / `cnb`) for POCO F7 Ultra (`miro`)

This is the executable runbook. It assumes the bring-up kit in this repo
(`manifest/`, `device/`, `vendor/`, `tools/`). Background and sources:
[`evolution-x-miro-bringup.md`](evolution-x-miro-bringup.md).

---

## 0. Host requirements

| Resource | Minimum | This machine |
| --- | --- | --- |
| CPU | 12 cores | 20 ✅ |
| RAM | 64 GB (wiki); 32 GB works with `-j` tuning | 31 GB ⚠️ |
| Disk | **~400 GB** free (source ~120 GB + `out/` ~250 GB) | **46 GB ❌** |
| OS | Ubuntu 22.04/24.04 | Arch/Omarchy ⚠️ |

> **This machine cannot build Android locally.** You need either a bigger
> disk/server, or a build host. The kit is portable — push the repos and build remotely.
> Use a dedicated build machine/CI; do not try to squeeze A17 into 46 GB.

Where the disk goes (AOSP's own figure is 250 GB checkout + 150 GB build):

| Component | Typical | Notes |
| --- | --- | --- |
| `.repo/` + working trees | 120–250 GB | ~1,300 git projects, prebuilt Clang/LLVM, Java/Go/Rust toolchains |
| `out/` | 100–200 GB | `out/soong`, intermediates, images |
| `ccache` (optional) | +50–100 GB | not required |
| **single-device build, no ccache** | **~250 GB** | realistic minimum |

Reduction settings:

```bash
repo sync -c --no-tags --no-clone-bundle   # current branch only
export USE_CCACHE=0                         # or CCACHE_SIZE=30G
export OUT_DIR=/mnt/bigdisk/out             # keep out/ off the root fs
m evolution                                 # build only the target, never a full AOSP image
```

So the extraction/device-tree work in this kit needs only a few GB; the 250–400 GB
only applies once you run `m evolution`.

Interesting packages (Debian/Ubuntu names; on Arch use the equivalents):

```bash
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf \
  lib32readline-dev lib32z1-dev libdw-dev libelf-dev lz4 libsdl1.2-dev libssl-dev \
  libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip \
  zlib1g-dev python-is-python3
```

---

## 1. Init the Evolution X `cnb` tree

```bash
mkdir -p ~/evo && cd ~/evo
repo init -u https://github.com/Evolution-X/manifest -b cnb --git-lfs
```

Install `repo` if needed:

```bash
mkdir -p ~/.local/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo
chmod a+x ~/.local/bin/repo
export PATH="$HOME/.local/bin:$PATH"
```

## 2. Add the miro local manifest

```bash
cp /path/to/evo-x-miro/manifest/miro.xml .repo/local_manifests/miro.xml
# (the manifest already points at github.com/sulthonuladib)

repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
```

What this pulls:

| Path | Source |
| --- | --- |
| `device/xiaomi/sm8750-common` | `Crisp-los/…sm8750-common` **`cnb`** (A17 tree, already has a `miro` path) |
| `device/xiaomi/miro`, `device/xiaomi/miro-kernel` | your repos |
| `vendor/xiaomi/miro`, `vendor/xiaomi/sm8750-common` | your repos (generated, §4) |
| `hardware/xiaomi` | `LineageOS/android_hardware_xiaomi` `lineage-24.0` |

The SM8750 CAF HALs (`hardware/qcom-caf/sm8750/audio/*`, `display/*`, `dataipa`) and
`device/qcom/sepolicy_vndr/sm8750` are already in the base `cnb` manifest — do not add them.

## 3. Signing keys

Unofficial:

```bash
git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template \
  vendor/evolution-priv/keys
cd vendor/evolution-priv/keys && ./keys.sh
```

**Back these up.** Losing them breaks dirty-flash OTA and Play Integrity.

## 4. Populate `device/xiaomi/miro-kernel` and the vendor trees

From this kit (see `tools/README.md` for detail):

```bash
tools/extract-stock-rom.sh ~/Downloads/miro-recovery-rom.zip work/images

export ANDROID_BUILD_TOP=~/evo
tools/unpack-kernel-artifacts.sh work/images ~/evo/device/xiaomi/miro-kernel

cd ~/evo/device/xiaomi/miro          && ./extract-files.py  /abs/path/work/images && ./setup-makefiles.py
cd ~/evo/device/xiaomi/sm8750-common && ./extract-files.py  /abs/path/work/images && ./setup-makefiles.py
```

Then **verify** the values in `device/xiaomi/miro/BoardConfig.mk`:

- `MIRO_KERNEL_VERSION` — must match the `system_dlkm/lib/modules/<version>` directory.
- `BOARD_SUPER_PARTITION_SIZE` / `BOARD_QTI_DYNAMIC_PARTITIONS_SIZE` — confirm with
  `lpdump` in recovery or by reading the stock super image. Stock reports
  `9126805504` / `9122611200`.
- AVB rollback indexes live in `device/xiaomi/sm8750-common/BoardConfigCommon.mk`
  (`XIAOMI_SM8750_SECURITY_PATCH`). Set it **at or above** the SPL reported by the
  firmware you actually flash.

Push the generated `device/xiaomi/miro`, `device/xiaomi/miro-kernel`, `vendor/xiaomi/miro`,
`vendor/xiaomi/sm8750-common` to your GitHub (or keep them local and drop the
corresponding `<project>` lines from the manifest).

## 5. Lunch and build

```bash
cd ~/evo
. build/envsetup.sh
lunch          # pick the lineage_miro-<release>-userdebug target from the menu
m evolution
```

> The Android 16+ lunch format is `lineage_<device>-<release>-<buildtype>`. The
> `<release>` token is chosen by the Evolution X build system; the `lunch` menu lists
> the exact valid combinations for `miro`.

The OTA package lands at:

```
out/target/product/miro/EvolutionX-17.0-<date>-miro-<version>-Unofficial.zip
out/target/product/miro/miro.json          # OTA metadata
```

## 6. OTA

Follow <https://wiki.evolution-x.org/custom-ota/cloudflare-ota>. The overlay to add is:

```
device/xiaomi/miro/overlay-evolution/Updater/res/values/strings.xml
```

```xml
<resources xmlns:xliff="urn:oasis:names:tc:xliff:document:1.2">
  <string name="updater_server_url" translatable="false">https://raw.githubusercontent.com/sulthonuladib/OTA/cnb/builds/miro.json</string>
  <string name="menu_changelog_url" translatable="false">https://raw.githubusercontent.com/sulthonuladib/OTA/cnb/changelogs/<xliff:g id="device_name">%1$s</xliff:g>.txt</string>
</resources>
```

## 7. Bring-up checklist / known TODOs

- [ ] First boot with stock kernel + stock modules (Strategy A).
- [ ] `lpdump` on the device to confirm super layout; adjust `BoardConfig.mk`.
- [ ] Fingerprint/UDFPS enrolls and unlocks (`TARGET_HAS_UDFPS := true`).
- [ ] RIL / VoLTE / VoWiFi (`ENABLE_VENDOR_RIL_SERVICE := true` in common tree).
- [ ] WLAN / BT / NFC.
- [ ] Display: 120 Hz switching, Dolby Vision, correct density (600).
- [ ] Camera provider + a camera app with parity (CameraMind, live photo).
- [ ] IR blaster (`consumerir`).
- [ ] Wireless charging (SC96281) + 120 W wired charging.
- [ ] QTI haptics (`/sys/class/qcom-haptics`).
- [ ] Add `FrameworkResOverlayMiro` / `SystemUIOverlayMiro`, `displayconfig`,
      touch-feature app, vibrator HAL (see `device/xiaomi/miro/device.mk` TODOs).
- [ ] SELinux **enforcing** (the `cnb` tree is enforcing; do not add permissive).
- [ ] OTA: build, sign, publish `miro.json`, dirty-flash an update end-to-end.
- [ ] Play Integrity (sign with your keys; may need PIF on A17).

## 8. Reference trees (for copying configs)

- `xiaomi-haotian-devs/android_device_xiaomi_haotian` — A16 device tree; overlays, touch,
  vibrator HAL, `displayconfig`, `sepolicy`.
- `xiaomi-dada/*` — A16 from-source kernel + full dependency list.
- `Crisp-los/android_device_xiaomi_sm8750-common` **`cnb`** — the A17 common baseline.
- `LineageOS/android_device_oneplus_sm8750-common` `lineage-24.0` — another A17 SM8750 tree.
