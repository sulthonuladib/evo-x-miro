#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from miro device
$(call inherit-product, device/xiaomi/miro/device.mk)

# Inherit some common Lineage / Evolution X stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Inherit from products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

PRODUCT_BRAND := POCO
PRODUCT_DEVICE := miro
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_MODEL := POCO F7 Ultra
PRODUCT_NAME := lineage_miro

# Stock build identity (used for Play Integrity / assorted device checks).
# TODO(miro): replace with the exact BuildFingerprint/AOSP build id read from the
# extracted OS3.0.302.0.WOMIDXM (Android 16 / HyperOS 3) system build.prop.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="missi-user 16 AQ3A.250605.031.A3 OS3.0.302.0.WOMIDXM release-keys" \
    BuildFingerprint=qti/missi/missi:16/AQ3A.250605.031.A3/OS3.0.302.0.WOMIDXM:user/release-keys \
    DeviceProduct=miro \
    SystemName=miro_global

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

# Xiaomi/QTI boot classpath jars. Appended last (after the AOSP base products
# are inherited below) so the ART boot image is generated with core-oj /
# framework first; a boot jar ordered before its dependencies crashes dex2oat
# with "Check failed: type_id != nullptr".
PRODUCT_BOOT_JARS += \
    telephony-ext \
    xiaomi-telephony-stub
