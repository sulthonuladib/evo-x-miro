# HANDOFF — Evolution X `cnb` on `miro`

> **Session handoff.** Written 2026-10-15 at the end of the vendor-tree + source-sync
> session. Read this first, then `PLAN.md` → "Current status". Delete/refresh it once its
> contents are folded into `PLAN.md`.

## Goal right now

Get to a **first `m evolution` build** of Evolution X (Android 17 / `cnb`) for POCO F7 Ultra
(`miro`) on this machine, and triage the first `check_elf` / missing-module errors.

Phases 0 (research/kit), 2 (stock ROM → kernel artifacts) and 3 (vendor trees) are **done**.
Phase 1 (source sync) is **finishing**; Phase 4 (first build) is next.

## Current state

- **Kit repo:** `~/personal/evo-x-miro` @ `main`, latest commit `88551b1`.
- **Build tree:** `/mnt/games/evo` — `repo init -u https://github.com/Evolution-X/manifest
  -b cnb --partial-clone --clone-filter=blob:limit=10M --git-lfs`, with
  `manifest/miro.xml` copied to `.repo/local_manifests/`.
- **A `repo sync` re-run is in progress** (started to recover 4 projects the first pass
  missed). Log: `/mnt/games/evo/repo-sync2.log`. Check it finished with:
  ```bash
  pgrep -af '[m]ain.py.*sync' || echo SYNC_DONE
  ```
  The first pass reported errors in `platform/system/unwinding`,
  `platform/external/perfmark`, `platform/external/python/cpython3`,
  `platform/external/skia` (transient network). `repo sync` again is the fix.
- **Published repos** (`github.com/sulthonuladib`, public, branch `cnb`):
  `android_device_xiaomi_miro`, `android_device_xiaomi_miro-kernel`,
  `proprietary_vendor_xiaomi_miro` (3 camera blobs in **Git LFS**),
  `proprietary_vendor_xiaomi_sm8750-common`.
- **Tools installed on this host:** `repo` 2.65 and `git-lfs` 3.8.0 in `~/.local/bin`;
  `fsck.erofs` in `~/.local/opt/erofs/usr/bin`.
- **Missing host packages:** `gnupg`, `gperf`, `schedtool`.
- **Disk:** `/mnt/games` 229 G used, **79 G free**; `/` 61 G free. Source ≈185 G
  (`.repo` ≈78 G + worktree ≈107 G). `out/` needs ~100–150 G, so free space first.

## Next commands (in order)

```bash
export PATH="$HOME/.local/bin:$PATH"
cd /mnt/games/evo

# 1) finish the sync; confirm SYNC_DONE
repo sync -c -j8 --force-sync --no-clone-bundle --no-tags
pgrep -af '[m]ain.py.*sync' || echo SYNC_DONE

# 2) free disk BEFORE building
mv /mnt/games/miro-files/*.tgz /path/to/external/   # 9.2 G, re-downloadable (optional)
rm -rf /mnt/games/miro-work                          # 14 G, regenerable
# last resort once the sync is green (breaks `repo` until re-init, frees ~78 G):
# rm -rf /mnt/games/evo/.repo

# 3) host packages
sudo pacman -S --needed gnupg gperf schedtool

# 4) signing keys (then back them up off-machine)
git clone https://github.com/Evolution-X/vendor_evolution-priv_keys-template \
    vendor/evolution-priv/keys
cd vendor/evolution-priv/keys && ./keys.sh && cd /mnt/games/evo

# 5) build
. build/envsetup.sh
lunch                     # choose lineage_miro-<release>-userdebug
USE_CCACHE=0 m -j6 evolution
```

`out/` defaults to `/mnt/games/evo/out` (same fs as the source). Watch
`df -h /mnt/games`; if it fills, stop and tell the next session.

## What to hand back to the agent

- **On failure (expected first):** the first Soong/ninja **error block** (e.g. `check_elf`
  "cannot find lib…", duplicate module, missing source). Fixes go in
  `device/xiaomi/miro/extract-files.py` (`blob_fixups`) or
  `device/xiaomi/miro/proprietary-files.txt`, then regenerate with
  `./setup-makefiles.py` and negotiate the vendor repos.
- **On success:** `ls -la out/target/product/miro/` and whether `EvolutionX-*.zip` +
  `miro.json` exist.

## Open decisions

1. **Licensing** — the four new repos are **public** and
   `proprietary_vendor_xiaomi_miro` hosts Dolby/Leica/ArcSoft blobs. Make them private
   (then `repo sync` needs auth) or strip the restricted blobs.
2. **Common-tree fork** — `Crisp-los/android_device_xiaomi_sm8750-common` still lists 11
   entries absent on `miro` (ST NFC, `libtouchreport_alg.so`, 32-bit gralloc/mapper, the
   32-bit touchfeature copy rule). A fork+prune makes extraction reproducible. Not needed
   for the build, only for regeneration.
3. **`check_elf`** — the real triage needs the build; static analysis flagged 267
   `DT_NEEDED` names (mostly source-built AOSP/QTI interfaces) plus a few miro-owned
   version mismatches. See `PLAN.md` Phase 3.

## Key paths

| What | Where |
| --- | --- |
| Kit | `~/personal/evo-x-miro` |
| Build tree | `/mnt/games/evo` (`out/` same fs) |
| Stock ROM zips | `/mnt/games/miro-files/` (`OS3.0.302.0.WOMIDXM`) |
| Dumped images | `/mnt/games/miro-work/images/` |
| extract-utils (gitignored) | `~/personal/evo-x-miro/tools/extract-utils` |
| prebuilt tool shims (gitignored) | `~/personal/evo-x-miro/prebuilts/` |
| Published repos | `github.com/sulthonuladib/*` @ `cnb` |

## Relevant commits (kit)

- `88551b1` — context-window/handoff convention; build-tree state.
- `87c59a1` — manifest XML fix (`--` inside a comment).
- `2acad2b` — Phase 3: vendor trees.
- `e512c30` — build runbook prerequisites + super-size fix.
