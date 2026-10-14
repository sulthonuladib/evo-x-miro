#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/xiaomi/miro
KERNEL_PATH := $(DEVICE_PATH)-kernel

# Stock kernel version string. This is the `uname -r`-style localversion used by
# the stock vendor_dlkm/system_dlkm module directories. Re-derive it from the
# stock ROM if you update the kernel baseline.
# TODO(miro): the scaffold used the OS2.0.107.0 value; OS3.0.302.0.WOMIDXM may differ.
MIRO_KERNEL_VERSION := 6.6.30-android15-8-gc6f5283046c6-ab12364222-4k

# Inherit from sm8750-common (A17 / cnb)
include device/xiaomi/sm8750-common/BoardConfigCommon.mk

# Partitions
#
# IMPORTANT: the common tree hardcodes the Xiaomi 15 Pro super size (11811160064).
# miro's physical super partition is SMALLER; flashing a super built at the wrong
# size fails. Verify the real values with `lpdump` in recovery before flashing.
# (The OS3.0.302.0 fastboot ROM's super/GPT is the authoritative source.)
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 9122611200

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
