#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from sm8750-common
$(call inherit-product, device/xiaomi/sm8750-common/common.mk)

# Evolution X: ultrasonic in-display fingerprint sensor
TARGET_HAS_UDFPS := true

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# Vendor blobs
$(call inherit-product, vendor/xiaomi/miro/miro-vendor.mk)

# ---------------------------------------------------------------------------
# TODO(miro): device-specific packages to port from a working SM8750 tree.
#
#   * Framework/SystemUI overlays (rounded corners, status bar height, etc.)
#   * displayconfig (display_id_*.xml) for the 6.67" WQHD+ panel
#   * Touch feature app (Xiaomi touchfeature / edge suppression)
#   * Vibrator HAL wrapper for /sys/class/qcom-haptics (QTI haptics)
#
# See docs/build-cnb.md for the bring-up checklist.
# ---------------------------------------------------------------------------
