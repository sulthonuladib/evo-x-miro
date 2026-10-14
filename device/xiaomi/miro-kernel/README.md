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
    └── 6.6.30-android15-8-gc6f5283046c6-ab12364222-4k/
        └── *.ko              # GKI modules for the system_dlkm partition
```

The directory name under `system_dlkm/` must match
`MIRO_KERNEL_VERSION` in `device/xiaomi/miro/BoardConfig.mk`.

## How to populate it

Everything here is produced by `tools/extract-stock-rom.sh` +
`tools/unpack-kernel-artifacts.sh` from the stock recovery ROM. The short version:

```bash
# 1. recovery ROM -> partition images
tools/extract-stock-rom.sh /path/to/miro-recovery-rom.zip  work/images

# 2. images -> device/xiaomi/miro-kernel
tools/unpack-kernel-artifacts.sh work/images               device/xiaomi/miro-kernel
```

Both scripts are thin wrappers around AOSP's `unpack_bootimg`, `payload-dumper-go`,
`avbtool` and a read-only mount of the `vendor_dlkm` / `system_dlkm` images.

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
