#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: 2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.fixups_lib import (
    lib_fixup_remove,
    lib_fixups,
    lib_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/xiaomi/miro',
    'device/xiaomi/sm8750-common',
    'hardware/qcom-caf/wlan',
    'hardware/qcom-caf/sm8750',
    'hardware/xiaomi',
    'vendor/qcom/opensource/commonsys/display',
    'vendor/qcom/opensource/commonsys-intf/display',
    'vendor/qcom/opensource/dataservices',
    'vendor/xiaomi/sm8750-common',
]


def lib_fixup_vendor_suffix(lib: str, partition: str, *args, **kwargs):
    return f'{lib}-{partition}' if partition == 'vendor' else None


lib_fixups: lib_fixups_user_type = {
    **lib_fixups,

    (
        'vendor.qti.diaghal-V1-ndk',
        'vendor.qti.ImsRtpService-V1-ndk',
    ): lib_fixup_vendor_suffix,

    (
        'libmialgo',
        'libaudioserviceexampleimpl',
    ): lib_fixup_remove,
}

# Device-specific fixups. The common-tree fixups live in
# device/xiaomi/sm8750-common/extract-files.py and only apply to files owned by
# the common list; the entries below are miro-owned copies of the same shims.
# Add to this dict when extract-files.py reports unresolved NEEDED entries.
blob_fixups: blob_fixups_user_type = {
    'vendor/lib64/libwfdmmsrc_proprietary.so': blob_fixup()
        .replace_needed(
            'android.media.audio.common.types-V2-ndk.so',
            'android.media.audio.common.types-V3-ndk.so',
        ),
    'vendor/lib64/hw/libaudiocorehal.qti.so': blob_fixup()
        .replace_needed(
            'android.hardware.audio.core.sounddose-V1-ndk.so',
            'android.hardware.audio.core.sounddose-V2-ndk_xiaomi.so',
        ),
    'vendor/lib64/libaudioserviceexampleimpl.so': blob_fixup()
        .add_needed('libaudioutils_shim.so')
        .replace_needed(
            'android.hardware.audio.core.sounddose-V2-ndk.so',
            'android.hardware.audio.core.sounddose-V2-ndk_xiaomi.so',
        )
        .replace_needed(
            'android.hardware.bluetooth.audio-impl.so',
            'android.hardware.bluetooth.audio-impl_xiaomi.so',
        )
        .replace_needed(
            'libbluetooth_audio_session_aidl.so',
            'libbluetooth_audio_session_aidl_xiaomi.so',
        )
        .replace_needed(
            'libaudio_aidl_conversion_common_ndk.so',
            'libaudio_aidl_conversion_common_ndk_xiaomi.so',
        ),
    'vendor/lib64/hw/libaudioeffecthal.qti.so': blob_fixup()
        .binary_regex_replace(b'libtinyxml2.so\x00', b'libtinyxmlQ.so\x00'),
    'vendor/lib64/libsxrservice.so': blob_fixup()
        .replace_needed(
            'android.hardware.common-V2-ndk_platform.so',
            'android.hardware.common-V2-ndk.so',
        ),
}

module = ExtractUtilsModule(
    'miro',
    'xiaomi',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    check_elf=True,
)

if __name__ == '__main__':
    utils = ExtractUtils.device_with_common(
        module, 'sm8750-common', module.vendor
    )
    utils.run()
