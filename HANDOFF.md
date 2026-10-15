# HANDOFF — Evolution X `cnb` on `miro`

> **Session handoff.** Written 2026-10-15 immediately before launching the first
> `m evolution` build. Read this first, then `PLAN.md` → "Current status".
> Delete/refresh once its contents are folded into `PLAN.md`.

## Goal right now

Get the **first `m -j6 evolution` build** of Evolution X (Android 17 / `cnb`) for POCO F7 Ultra
(`miro`) on this machine to succeed, then triage the first `check_elf` / missing-module errors.

Phases 0–3 are **done**. Phase 1 (source sync) is **complete**. Phase 4 (first build) is
**in progress**.

## Current state

- **Kit repo:** `~/personal/evo-x-miro` @ `main`, latest commit `ad70c1b`.
- **Build tree:** `/mnt/games/evo`, branch `cnb`, fully synced.
  `repo-sync2.log` ends with **"repo sync has finished successfully."** All four
  previously-failed projects (`platform/system/unwinding`, `platform/external/perfmark`,
  `platform/external/python/cpython3`, `platform/external/skia`) are checked out.
- **Signing keys:** `vendor/evolution-priv/keys` generated via the template's `keys.sh`
  (~179 files incl. `avb_custom_key.bin`, `releasekey.pk8 -> testkey.pk8`).
  `vendor/lineage/config/evolution.mk` includes `keys.mk` (optional `-include` for Unofficial).
  **Not backed up off-machine yet.**
- **Host tools:** `repo` 2.65 + `git-lfs` 3.8.0 in `~/.local/bin`; `fsck.erofs` in
  `~/.local/opt/erofs/usr/bin`; `gpg` 2.4.9, `gperf`, `schedtool`, `avbtool`, `openssl` present.
  `gnupg` meta package not installed (`sudo` needs a password) — harmless.
- **Disk:** `/mnt/games` ~103 GB free; `/` ~44 GB free. `.repo` ~78 GB still present.
  `out/` has not been created yet.
- **Lunch:** `lineage_miro-userdebug` →
  `EvolutionX-17.0-20261015-miro-12.3-Unofficial`, `PLATFORM_VERSION=17`,
  `TARGET_DEVICE=miro`, `WITH_GMS=true`.

## Next commands (in order)

```bash
export PATH="$HOME/.local/bin:$PATH"
cd /mnt/games/evo

# 1) build (background; log to build.log)
. build/envsetup.sh
lunch lineage_miro-userdebug
USE_CCACHE=0 m -j6 evolution > build.log 2>&1 &
echo $! > build.pid

# 2) watch
tail -f build.log
df -h /mnt/games          # if free < ~15 GB, stop and: rm -rf /mnt/games/evo/.repo

# 3) on success
ls -la out/target/product/miro/
```

If the build is not already running when you re-read this, just run step 1.

## What to hand back to the agent

- **On failure (expected first):** the first Soong/ninja **error block** (e.g. `check_elf`
  "cannot find lib…", duplicate module, missing source). Fixes go in
  `device/xiaomi/miro/extract-files.py` (`blob_fixups`) or
  `device/xiaomi/miro/proprietary-files.txt`, then regenerate with
  `./setup-makefiles.py` and negotiate the vendor repos.
- **On success:** `ls -la out/target/product/miro/` and whether `EvolutionX-*.zip` +
  `miro.json` exist.

## Open decisions

1. **Licensing** — the four `sulthonuladib` repos are **public** and
   `proprietary_vendor_xiaomi_miro` hosts Dolby/Leica/ArcSoft blobs. Make them private
   (then `repo sync` needs auth) or strip the restricted blobs.
2. **Common-tree fork** — `Crisp-los/android_device_xiaomi_sm8750-common` still lists 11
   entries absent on `miro` (ST NFC, `libtouchreport_alg.so`, 32-bit gralloc/mapper, the
   32-bit touchfeature copy rule). A fork+prune makes extraction reproducible. Not needed
   for the build, only for regeneration.
3. **`check_elf`** — the real triage needs the build; static analysis flagged 267
   `DT_NEEDED` names (mostly source-built AOSP/QTI interfaces) plus a few miro-owned
   version mismatches. See `PLAN.md` Phase 3.
4. **`.repo` prune** — deleting `/mnt/games/evo/.repo` frees ~78 GB but breaks `repo` until
   re-init (no re-download of worktree needed; re-init + sync is a full re-fetch). Do it only
   if `out/` runs the disk low.

## Key paths

| What | Where |
| --- | --- |
| Kit | `~/personal/evo-x-miro` |
| Build tree | `/mnt/games/evo` (`out/` same fs) |
| Build log | `/mnt/games/evo/build.log` |
| Stock ROMs (moved) | `/home/sulthonuladib/stock-roms/` (`OS3.0.302.0.WOMIDXM`) |
| Signing keys | `/mnt/games/evo/vendor/evolution-priv/keys` |
| extract-utils (gitignored) | `~/personal/evo-x-miro/tools/extract-utils` |
| Published repos | `github.com/sulthonuladib/*` @ `cnb` |

## Relevant commits (kit)

- `ad70c1b` — durable session handoff for Phase 1 → Phase 4.
- `88551b1` — context-window/handoff convention; build-tree state.
- `2acad2b` — Phase 3: vendor trees.
