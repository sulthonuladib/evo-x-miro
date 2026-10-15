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
    'hardware/qcom-caf/wlan/qcwcn',
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

    # libmdnssd is only visible to minadbd/adb in Soong; the Miracast system_ext
    # blob links it at runtime from the platform. Drop the build-time dep.
    'libmdnssd': lib_fixup_remove,

    (
        'vendor.qti.diaghal-V1-ndk',
        'vendor.qti.ImsRtpService-V1-ndk',
    ): lib_fixup_vendor_suffix,

    (
        'libmialgo',
        'libaudioserviceexampleimpl',
    ): lib_fixup_remove,
}

# miro-owned blobs only. The shared audio/display shims that used to be seeded
# here now live in device/xiaomi/sm8750-common/extract-files.py: the blobs they
# patch are owned by the common tree (the device list no longer duplicates
# them), so the common module applies those fixups. Keep this dict in sync with
# the device list when regenerating from a new dump.
blob_fixups: blob_fixups_user_type = {
    # The QTI sound trigger HAL was built against the V2 AIDL audio types; the
    # tree ships the V3/V6 interface modules. Same shim as the common tree's
    # audio HALs (see sm8750-common/extract-files.py).
    'vendor/lib64/hw/libsoundtriggerhal.qti.so': blob_fixup()
        .replace_needed(
            'android.media.audio.common.types-V2-ndk.so',
            'android.media.audio.common.types-V3-ndk.so',
        ),

    # OS3 stock blobs whose DT_SONAME does not match their file name (Soong
    # check_elf_file rejects the mismatch). The Hexagon rfs/dsp/*_skel.so
    # blobs also mismatch but are skipped by --skip-unknown-elf-machine.
    'odm/lib64/libSnpeHtpV79CalculatorStub.so': blob_fixup().fix_soname(),
    'odm/lib64/libhta_hexagon_runtime_snpe.so': blob_fixup().fix_soname(),
    'odm/lib64/libmiam.so': blob_fixup().fix_soname(),
    'odm/lib64/libremosaiclib_s5kjn5.so': blob_fixup().fix_soname(),
    'odm/lib64/libremosaiclib_s5kkd1.so': blob_fixup().fix_soname(),
    'odm/lib64/libtouchreport_alg_2.so': blob_fixup().fix_soname(),
    'odm/lib64/libtouchreport_alg_fts.so': blob_fixup().fix_soname(),
}

module = ExtractUtilsModule(
    'miro',
    'xiaomi',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
    check_elf=False,
)

if __name__ == '__main__':
    utils = ExtractUtils.device_with_common(
        module, 'sm8750-common', module.vendor
    )
    utils.run()
