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
# TODO(miro): update when you rebase onto a newer stock firmware.
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="missi-user 15 AQ3A.240829.003 OS2.0.107.0.VOMMIXM release-keys" \
    BuildFingerprint=qti/missi/missi:15/AQ3A.240829.003/OS2.0.107.0.VOMMIXM:user/release-keys \
    DeviceProduct=miro \
    SystemName=miro_global

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi
