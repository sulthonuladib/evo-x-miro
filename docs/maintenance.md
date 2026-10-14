# Maintenance: staying in sync (Evolution X + firmware)

Two independent update streams. Do not confuse them:

| Stream | What changes | Where it comes from | Affects |
| --- | --- | --- | --- |
| **ROM source** | Android/Evolution X code | `repo sync` from `Evolution-X/*` | `/system`, `/system_ext`, `/product` |
| **Firmware** | bootloader, modem, DSP, TZ, … | stock **fastboot** ROM | `abl`, `xbl`, `tz`, `modem`, … |
| **Vendor blobs** | HALs, camera, audio, display libs | stock **recovery** ROM | `/vendor`, `/odm`, `/system_ext` |
| **Kernel + modules** | kernel, GKI + vendor modules | stock recovery ROM (or OSS kernel build) | `boot`, `vendor_dlkm`, `system_dlkm` |

The custom ROM replaces the *system* side. Firmware and vendor blobs only change when
**you** incorporate a new stock release.

---

## Part A — Keeping in sync with Evolution X

### The routine

```bash
cd ~/evo
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
. build/envsetup.sh
lunch lineage_miro-<release>-userdebug
m evolution
```

`repo sync` updates every project in the `cnb` manifest to the latest commit on its
tracked branch. Rebuilding after a sync produces a new ROM; publish it via your OTA
(see `build-cnb.md` §6).

### Rules that keep syncs painless

- **Your trees live in your own repos.** `device/xiaomi/miro`, `device/xiaomi/miro-kernel`,
  `vendor/xiaomi/miro`, `vendor/xiaomi/sm8750-common` are declared in `manifest/miro.xml`
  with your remote. `repo sync` will update them too — so **push your work**, don't rely on
  uncommitted local edits.
- **Never commit to Evolution X repos.** If you need a patch in an EvoX repo, fork it and
  override it in your local manifest:

  ```xml
  <remove-project name="Evolution-X/frameworks_base" />
  <project path="frameworks/base" name="yourid/frameworks_base" revision="cnb" remote="github" />
  ```

  Then `repo sync` updates your fork instead of conflicting with the upstream branch.
- **Check before syncing:**

  ```bash
  repo status                 # local modifications per project
  repo diff                   # the actual diffs
  repo forall -c 'git log --oneline @{u}..'   # local commits not upstream
  ```

- **`repo sync -d`** detaches HEAD and discards local commits in every project. Useful to
  un-wedge the EvoX repos, **never** run it on your device tree.
- **Weekly cadence** is enough. Evolution X merges the monthly Android Security Bulletin;
  a `repo sync` + rebuild picks it up.
- **When `cnb` rebases onto a new AOSP QPR**, the build may break against your device tree.
  That's the moment to `repo sync`, fix the device tree, and tag a new release. Watch the
  Evolution X Telegram/Discord and the `cnb` commit log.
- **Rebase, don't merge**, for your device tree: keep it as a clean stack on top of
  `sm8750-common` so future syncs are trivial.

### If the device becomes official

Evolution X hosts the OTA server and rebuilds for you; you keep the device tree current.
Until then, you are the release engineer (below).

---

## Part B — Firmware and vendor-blob updates

### What triggers an update

Xiaomi ships a new HyperOS build for `miro` (new `OS2.x.y.z.VOMMIXM` / `VOMCNXM`).
Depending on what changed, you regenerate one or more of:

| Changed in the new stock ROM | Regenerate |
| --- | --- |
| `vendor` / `odm` / `system_ext` / `product` | `vendor/xiaomi/miro` (+ common) via `extract-files.py` |
| `boot` / `init_boot` / `vendor_boot` / `dtbo` / `*-dlkm` | `device/xiaomi/miro-kernel` via `tools/`, bump `MIRO_KERNEL_VERSION` |
| `xbl` / `abl` / `tz` / `modem` / `dsp` / … | `vendor/xiaomi/miro-firmware` via `proprietary-firmware.txt` |

Then **always**:

1. Bump the security patch / AVB rollback index in
   `device/xiaomi/sm8750-common/BoardConfigCommon.mk`:

   ```make
   XIAOMI_SM8750_SECURITY_PATCH := <new SPL, e.g. 2026-05-01>
   XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP := <unix ts>
   ```

   This must be **≥** the SPL the new firmware reports in the bootloader, or the
   bootloader rejects the freshly flashed inactive slot. This is the single most
   common cause of "OTA installs then won't boot".

2. Rebuild, test, and only then publish.

### How users receive firmware

**Option 1 — firmwareless ROM (default, recommended).**
The ROM contains only the system side. Users flash a firmware-only zip separately:

- **XiaomiFirmwareUpdater** publishes recovery-flashable firmware-only zips for `miro`:
  <https://github.com/XiaomiFirmwareUpdaterReleases/firmware_xiaomi_miro>
  (tags like `stable-31.10.2025`). These flash firmware to **both slots**.
- Or build your own from `proprietary-firmware.txt` + `extract-files.py --extract-factory`.
- Document the required firmware baseline in your release notes / XDA thread.

**Option 2 — firmware-in-OTA.**
`extract_utils` can generate `vendor/xiaomi/miro/BoardConfigFirmware.mk`, which appends the
firmware partitions to `AB_OTA_PARTITIONS`:

```make
# Optional <version> firmware payload. Normal ROM builds remain firmwareless.
AB_OTA_PARTITIONS += \
    abl aop aop_config bluetooth cpucp cpucp_dtb devcfg dsp featenabler \
    hyp idmanager imagefv keymaster modem modemfirmware multiimgqti pdp \
    pdp_cdb pvmfw qupfw shrm soccp_dcd soccp_debug spuservice tz uefi \
    uefisecapp xbl xbl_config xbl_ramdump
```

`device/xiaomi/miro/BoardConfig.mk` then includes it when enabled:

```make
ifeq ($(TARGET_INCLUDE_FIRMWARE),true)
include vendor/xiaomi/miro/BoardConfigFirmware.mk
endif
```

With `TARGET_INCLUDE_FIRMWARE=true`, the OTA `payload.bin` updates firmware in lockstep, so
users never flash firmware manually.

- ✅ one zip, users stay current.
- ⚠️ anti-rollback applies immediately (see below); a bad firmware bricks; payload is bigger.
- The upstream default is firmwareless — treat Option 2 as an opt-in.

### "Firmware update from my phone"

A phone running the custom ROM will **not** receive HyperOS updates, so there is no
firmware to capture from it. Get firmware from the stock packages instead:

1. **Official ROM packages** — recovery/fastboot ROM from Xiaomi or a mirror
   (e.g. xmfirmwareupdater.com, mirom.ezbox.idv.tw, the XFU repos).
2. **A stock (unmodified) miro** — enable the HyperOS OTA, let it download, and pull the
   zip from `/data/...` / `Download/` before installing. Same packages as (1).
3. **Extract** the firmware images with `proprietary-firmware.txt` and `extract_utils`
   (`--extract-factory`), then either flash them via a firmware zip or fold them into the
   ROM via Option 2.

Once you ship firmware-in-OTA (Option 2), "firmware update" for your users is just the
normal ROM OTA — no separate step.

### Anti-rollback — read this before flashing firmware

- Xiaomi bootloaders enforce an **anti-rollback fuse/index**. Flashing *newer* firmware
  with a higher rollback index is irreversible; you cannot flash *older* firmware again.
- Do not downgrade firmware to "fix" a bad build. Match the ROM's
  `XIAOMI_SM8750_SECURITY_PATCH` to the firmware you ship.
- Keep both A/B slots consistent (firmware zips normally do this).
- Back up the `persist` partition before any firmware change.
- If a new firmware ships a higher SPL, bump your BoardConfig in the **same** commit that
  updates the blobs — never ship blobs and firmware out of step.

---

## Part C — Releasing an update (unofficial)

```bash
m evolution
# out/target/product/miro/EvolutionX-...-miro-...-Unofficial.zip
# out/target/product/miro/miro.json

# publish payload + JSON + changelog
cp out/target/product/miro/miro.json  ~/OTA/builds/miro.json
$EDITOR ~/OTA/builds/miro.json            # set download URL / md5 / sha256 / size
$EDITOR ~/OTA/changelogs/miro.txt
rclone copy out/target/product/miro/EvolutionX-*.zip r2:miro
cd ~/OTA && git add -A && git commit -m "miro: $(date +%F)" && git push
```

Users then see the update in Evolution X's Updater. Details:
<https://wiki.evolution-x.org/custom-ota/cloudflare-ota>.

## Checklist

- [ ] `repo sync` before every release; rebuild, don't ship a stale tree.
- [ ] Any local EvoX patch is in a fork + local manifest `<remove-project>`, not a local commit.
- [ ] On every stock update: blobs, kernel, firmware, **and rollback index** all bumped together.
- [ ] Firmware baseline documented in the release notes.
- [ ] `miro.json` hash/size correct or OTA verification fails.
