# `device/xiaomi/miro-kernel` — prebuilt kernel artifacts

This tree holds the **stock (or self-built) kernel artifacts** for the POCO F7 Ultra
(`miro`), so Evolution X does not have to build the kernel from source to boot. It mirrors
the layout used by the working SM8750 A17 trees (e.g.
`xiaomi-haotian-devs/android_device_xiaomi_haotian-kernel`).

`device/xiaomi/miro/BoardConfig.mk` consumes exactly these paths:

```
device/xiaomi/miro-kernel/
├── kernel                    # raw arm64 Image extracted from boot.img
├── dtb/                      # *.dtb (Soong globs *.dtb from here)
│   └── *.dtb
├── dtbo.img                  # prebuilt DTBO image
├── kernel-headers/           # headers_install tree (for TARGET_KERNEL_SOURCE)
├── prebuilt_kernel_headers.tar.gz
├── vendor_ramdisk/           # modules loaded by the vendor ramdisk / recovery
│   ├── *.ko
│   ├── modules.load
│   ├── modules.load.recovery
│   └── modules.blocklist
├── vendor_dlkm/              # modules that land in the vendor_dlkm partition
│   ├── *.ko
│   ├── modules.load
│   └── modules.blocklist
└── system_dlkm/
    └── 6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k/
        ├── kernel/…        # GKI modules for the system_dlkm partition
        └── modules.load    # paths are relative to this directory
```

The directory name under `system_dlkm/` must match
`MIRO_KERNEL_VERSION` in `device/xiaomi/miro/BoardConfig.mk`.

## How to populate it

Everything here is produced by `tools/extract-stock-rom.sh` +
`tools/unpack-kernel-artifacts.sh` from the stock recovery ROM. The short version:

```bash
# 1. recovery ROM -> partition images
tools/extract-stock-rom.sh /path/to/miro-recovery-rom.zip  work/images

# 2. images -> device/xiaomi/miro-kernel (needs erofs-utils for the stock images)
FSCK_EROFS=/path/to/fsck.erofs \
  tools/unpack-kernel-artifacts.sh work/images device/xiaomi/miro-kernel
```

The unpacker handles the real stock formats: EROFS `vendor_dlkm`/`system_dlkm` images,
the LZ4+cpio vendor ramdisk, and the 8 concatenated FDTs in `vendor_boot` (split into
`dtb/01_dtbdump_…` … `08_dtbdump_…`; the `NN_` prefixes keep the stock order). It prints
the kernel version and the `MIRO_KERNEL_VERSION` value to set. Intermediates land in
`.work/` and can be deleted after a successful run.

The current tree was produced from **OS3.0.302.0.WOMIDXM**:
`kernel` + `dtb/` + `dtbo.img` + 411 vendor-ramdisk modules + 380 vendor_dlkm modules +
96 system_dlkm modules.

`kernel-headers/` and `prebuilt_kernel_headers.tar.gz` are **not** produced from the stock
ROM. They are only needed for out-of-tree module builds and come from a kernel source
export (Strategy B, Phase 10) or a haotian-style mixed-provenance tarball. The paths in
`BoardConfig.mk` are inert until then.

## Strategy A vs B (see docs/evolution-x-miro-bringup.md §2.4)

- **Strategy A (this tree, recommended first):** use the stock kernel + stock modules.
  Fastest path to a booting ROM; guaranteed KMI/ABI match with the stock vendor blobs.
- **Strategy B (later):** build `MiCode/Xiaomi_Kernel_OpenSource` branch `bsp-miro-v-oss`
  with Kleaf, target `miro`, variant `consolidate`/`perf`, and drop the output here.
  Use this if you want KernelSU, kernel patches, or a newer ACK baseline.

If you build from source, the produced module directory will be named
`<version>-android15-8-…-4k`; update `MIRO_KERNEL_VERSION` to match.

## Do not remove

- `modules.load` files: P0 modules must load to bring up display/storage.
- `modules.blocklist`: prevents vendor_dlkm modules from being built into the generic
  ramdisk. Removing it breaks `init_boot`.
