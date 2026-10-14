#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/miro
KERNEL_PATH := $(DEVICE_PATH)-kernel

# Stock kernel version string. This is the `uname -r`-style localversion used by
# the stock vendor_dlkm/system_dlkm module directories. Re-derive it from the
# stock ROM if you update the kernel baseline (tools/unpack-kernel-artifacts.sh
# prints it). OS3.0.302.0.WOMIDXM ships 6.6.118, not the OS2.0.107.0 dump's 6.6.30.
MIRO_KERNEL_VERSION := 6.6.118-android15-8-ge56cf6b09cca-ab15511674-4k

# Inherit from sm8750-common (A17 / cnb)
include device/xiaomi/sm8750-common/BoardConfigCommon.mk

# Security patch / AVB rollback indexes.
#
# The common tree still carries the OS2.0.107.0 value (2026-02-01). The current
# stock baseline (OS3.0.302.0.WOMIDXM) reports post-security-patch-level
# 2026-08-01, so re-state the value and every index the common tree derived from
# it *after* the include (Make variables are assigned eagerly). Timestamp is
# 2026-08-01 00:00:00 UTC. Drop this block once sm8750-common is bumped past
# 2026-08-01. See docs/maintenance.md §B.
XIAOMI_SM8750_SECURITY_PATCH := 2026-08-01
XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP := 1785542400

BOOT_SECURITY_PATCH := $(XIAOMI_SM8750_SECURITY_PATCH)
VENDOR_SECURITY_PATCH := $(XIAOMI_SM8750_SECURITY_PATCH)

BOARD_AVB_BOOT_ROLLBACK_INDEX := $(XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := $(XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP)
BOARD_AVB_VBMETA_SYSTEM_ROLLBACK_INDEX := $(XIAOMI_SM8750_SECURITY_PATCH_TIMESTAMP)

# Partitions
#
# The common tree's 11 GiB super default is correct for the OS3.0.302.0 baseline:
# its fastboot GPT sizes super at 11534336 KiB = 11811160064, dynamic
# 11809841488. The old OS2.0.107.0 (Android 15) dump's 9126805504 / 9122611200
# do NOT apply after flashing the OS3.0.302.0 fastboot ROM. Confirm with `lpdump`
# on the device before flashing.

# Sepolicy
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Display
TARGET_SCREEN_DENSITY := 600

# Dtb/o
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PATH)/dtbo.img
# Soong's prebuilt DTB packaging only globs *.dtb from this directory.
BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PATH)/dtb

# Kernel
TARGET_NO_KERNEL_OVERRIDE := true

TARGET_KERNEL_SOURCE := $(KERNEL_PATH)/kernel-headers
TARGET_PREBUILT_KERNEL_HEADERS := $(KERNEL_PATH)/prebuilt_kernel_headers.tar.gz

PRODUCT_COPY_FILES += \
	$(KERNEL_PATH)/kernel:kernel

# Kernel modules
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/vendor_ramdisk/modules.load))

BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/vendor_ramdisk/modules.load.recovery))

BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/vendor_dlkm/modules.load))

PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(KERNEL_PATH)/vendor_dlkm/,$(TARGET_COPY_OUT_VENDOR_DLKM)/lib/modules) \
    $(filter-out $(KERNEL_PATH)/vendor_ramdisk/modules.load.recovery:$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules/modules.load.recovery,$(call find-copy-subdir-files,*,$(KERNEL_PATH)/vendor_ramdisk/,$(TARGET_COPY_OUT_VENDOR_RAMDISK)/lib/modules)) \
    $(call find-copy-subdir-files,*,$(KERNEL_PATH)/system_dlkm/$(MIRO_KERNEL_VERSION)/,$(TARGET_COPY_OUT_SYSTEM_DLKM)/lib/modules/$(MIRO_KERNEL_VERSION))

# Properties
TARGET_ODM_PROP += $(DEVICE_PATH)/configs/properties/odm.prop

# Inherit from the proprietary version
include vendor/xiaomi/miro/BoardConfigVendor.mk
