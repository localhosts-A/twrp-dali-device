#!/usr/bin/env bash
set -euo pipefail

EXPECTED_DTB_SHA256=223984cc1daf6f9194ff33e4c674dce9f2de9203dc9b73e72bd1e0754dbf4ae4
EXPECTED_DRM_SHA256=e65458654f987d673559004e5b0db132d78099adda4500a844e2c2412fbabd26
EXPECTED_PANEL_SHA256=fae1f2107488960175e5655ccdc7733213b257f8288a76e06576cceb46ea37e2
EXPECTED_MODULES_LOAD_SHA256=69c139937e534fab6b98481d33d195bf8d3c20a0c45eccc239ea3e84fbea852d
EXPECTED_MODULES_DEP_SHA256=dd972abacb2c2cd5475903b8ad681c9985d0a3be67fd2e6f65c812305be8034c
EXPECTED_SCP_SHA256=3aa2d9c09af01935149f348ff853c3f7069993d92e89892d32b92e8c8c49a392
EXPECTED_GOODIX_SHA256=1b07da57b40a16cc4dd3b221010c05e30df35c3ce8fecae05f9d91d09a496bd6
EXPECTED_XIAOMI_TOUCH_SHA256=115197fb99c2a56b9fc6111da3b4c1a323fd80e197b768253276e2f518674b20
EXPECTED_BOOT_HAL_SHA256=33b1dcb8da6170cc1fe9b3e6ecd7892c372ee2c8600f56fdaa113faeaaa03ad9
EXPECTED_HEALTH_HAL_SHA256=5c6c91509153383d7918cdf676bd4741921060dfc4c79a4eae919dd4a86dc290
EXPECTED_FASTBOOT_HAL_SHA256=3b4c1d9eaf7b602fbaec92015692dabd70e52a15f6e569ed976bdb503ddb7a96
EXPECTED_MTK_BSG_SHA256=820b7868ecb06a600427a8618ef8a7414e2020fe31757dc46ed02eef53da7a6e
EXPECTED_AVB_SALT=2db181f89cbfa19a432e02b260bc991097e8918da9f254461228ee6a2b264db8
EXPECTED_FRAMEWORK_MANIFEST_SHA256=cd5ae373388bd38d3d481a0b4a0b71f475d55f9a5221bbdf91c5b4da474560d3
EXPECTED_VENDOR_MANIFEST_SHA256=829f2ef4af116ee873b3d9967d19a56e01fa166ca33a07d6cd593043f2b05467
EXPECTED_VENDOR_MATRIX_SHA256=4f7a9adb5c005dedd20cb4373015e9ca7ac43ec4da8c8672d50f5e54bdafeafa
EXPECTED_BOOT_VINTF_SHA256=0fa13e87fd880e6476624f1467cecaaab034afc27c8fd39d6ee535dcb8be7a00
EXPECTED_HEALTH_VINTF_SHA256=25fe85c1947d8efa93b30c6dce65e830d92f87bb1035f0b837674f4f57873ae5
EXPECTED_VENDOR_FILE_CONTEXTS_SHA256=5b16f048139971939cee18cf11099965ade3ef8baf94b2d932135ece7bc1466c
EXPECTED_KEYMINT_MANIFEST_SHA256=b9d63a85f9f944ad20c1b200faf3a0928e773b3e175006def91980972ddff68f
EXPECTED_GATEKEEPER_MANIFEST_SHA256=43c9fa3229d506bd098da1079d4df3826636602b35c15d92c0328d83961a87e9
EXPECTED_WEAVER_MANIFEST_SHA256=953d4598323982fb9b37bf604e36fd724340dd797de4e56786564806a768face
STOCK_TOP_VBMETA_DIGEST=75254351fb4c27ccb69d60eab1c9aabf09de9abb791c7665137eca99241c87be
PARTITION_SIZE=67108864

TOP="${ANDROID_BUILD_TOP:-$(pwd)}"
OUT_BASE="${OUT_DIR:-out}"
[[ "$OUT_BASE" = /* ]] || OUT_BASE="$TOP/$OUT_BASE"
PRODUCT_OUT="${ANDROID_PRODUCT_OUT:-$OUT_BASE/target/product/dali}"
[[ "$PRODUCT_OUT" = /* ]] || PRODUCT_OUT="$TOP/$PRODUCT_OUT"

DEVICE="$TOP/device/xiaomi/dali"
CRYPTO_VINTF="$DEVICE/prebuilt/crypto_vintf"
CRYPTO_KEYSTORE_RC="$DEVICE/recovery/root/system/etc/init/keystore2.rc"
CRYPTO_DEVICE_POLICY="$DEVICE/sepolicy/vendor/crypto_devices.te"
DEPLOY="$PRODUCT_OUT/dali-deploy"
IMAGE="$DEPLOY/OrangeFox-dali-vendor_boot-dev.img"
RAW="$DEPLOY/vendor_boot-dali-raw.img"
PLATFORM="$DEPLOY/vendor_ramdisk_platform.lz4"
RECOVERY="$DEPLOY/vendor_ramdisk_recovery.lz4"
MINUI_SOURCE="$PRODUCT_OUT/system/lib64/libminuitwrp.so"
KEYSTORE2_SOURCE="$PRODUCT_OUT/system/bin/keystore2"
SE_OMAPI_SOURCE="$PRODUCT_OUT/system/bin/se_omapi"
DTB="$DEVICE/prebuilt/dtb/mt6991-stock.dtb"
RECOVERY_MODULES="$DEVICE/prebuilt/recovery_modules"
LZ4="$OUT_BASE/host/linux-x86/bin/lz4"
AVBTOOL="$TOP/external/avb/avbtool.py"
UNPACK_BOOTIMG="$TOP/system/tools/mkbootimg/unpack_bootimg.py"
REPORT="$DEPLOY/VERIFY_REPORT.txt"
SCRATCH="$(mktemp -d "$OUT_BASE/dali-verify.XXXXXX")"

case "$SCRATCH" in
    "$OUT_BASE"/dali-verify.*) ;;
    *) exit 2 ;;
esac

cleanup() {
    rm -rf -- "$SCRATCH"
}
trap cleanup EXIT

assert_sha256() {
    local expected="$1"
    local file="$2"
    test "$(sha256sum "$file" | awk '{print $1}')" = "$expected"
}

exec > >(tee "$REPORT") 2>&1

for file in "$IMAGE" "$RAW" "$PLATFORM" "$RECOVERY" "$MINUI_SOURCE" "$KEYSTORE2_SOURCE" "$SE_OMAPI_SOURCE" "$DTB" "$LZ4" \
    "$CRYPTO_VINTF/SHA256SUMS" \
    "$CRYPTO_KEYSTORE_RC" \
    "$CRYPTO_DEVICE_POLICY" \
    "$RECOVERY_MODULES/scp.ko" \
    "$RECOVERY_MODULES/goodix_core_dali.ko" \
    "$RECOVERY_MODULES/xiaomi_touch_dali.ko" \
    "$AVBTOOL" "$UNPACK_BOOTIMG" "$OUT_BASE/build-twrp_dali.ninja"; do
    test -s "$file"
done
assert_sha256 "$EXPECTED_VENDOR_FILE_CONTEXTS_SHA256" \
    "$CRYPTO_VINTF/vendor_file_contexts"

SOONG_INDEX="$OUT_BASE/soong/build.twrp_dali.ninja"
test -s "$SOONG_INDEX"
mapfile -t SOONG_NINJAS < <(awk '$1 == "subninja" {print $2}' "$SOONG_INDEX")
test "${#SOONG_NINJAS[@]}" -gt 0
for file in "${SOONG_NINJAS[@]}"; do
    test -s "$file"
done

platform_size="$(stat -c %s "$PLATFORM")"
recovery_size="$(stat -c %s "$RECOVERY")"
raw_size="$(stat -c %s "$RAW")"
test "$(stat -c %s "$IMAGE")" -eq "$PARTITION_SIZE"
assert_sha256 "$EXPECTED_DTB_SHA256" "$DTB"
test "$(od -An -tx1 -N4 "$PLATFORM" | tr -d ' \n')" = 02214c18
test "$(od -An -tx1 -N4 "$RECOVERY" | tr -d ' \n')" = 02214c18
"$LZ4" -t "$PLATFORM"
"$LZ4" -t "$RECOVERY"
cmp -n "$raw_size" "$RAW" "$IMAGE"

cp --reflink=auto "$IMAGE" "$SCRATCH/vendor_boot.img"
python3 "$AVBTOOL" verify_image --image "$SCRATCH/vendor_boot.img"
python3 "$AVBTOOL" info_image --image "$IMAGE" >"$SCRATCH/avb-info.txt"
grep -Eq '^Footer version:[[:space:]]+1\.0$' "$SCRATCH/avb-info.txt"
grep -Eq "^Image size:[[:space:]]+$PARTITION_SIZE bytes$" "$SCRATCH/avb-info.txt"
grep -Eq "^Original image size:[[:space:]]+$raw_size bytes$" "$SCRATCH/avb-info.txt"
grep -Eq "^VBMeta offset:[[:space:]]+$raw_size$" "$SCRATCH/avb-info.txt"
grep -Eq '^Authentication Block:[[:space:]]+0 bytes$' "$SCRATCH/avb-info.txt"
grep -Eq '^Algorithm:[[:space:]]+NONE$' "$SCRATCH/avb-info.txt"
grep -Eq "^[[:space:]]+Image Size:[[:space:]]+$raw_size bytes$" "$SCRATCH/avb-info.txt"
grep -Eq '^[[:space:]]+Hash Algorithm:[[:space:]]+sha256$' "$SCRATCH/avb-info.txt"
grep -Eq '^[[:space:]]+Partition Name:[[:space:]]+vendor_boot$' "$SCRATCH/avb-info.txt"
grep -F "Salt:                  $EXPECTED_AVB_SALT" "$SCRATCH/avb-info.txt" >/dev/null
max_raw_size="$(python3 "$AVBTOOL" add_hash_footer \
    --partition_size "$PARTITION_SIZE" --calc_max_image_size)"
test "$raw_size" -le "$max_raw_size"
final_digest="$(awk '$1 == "Digest:" {print $2; exit}' "$SCRATCH/avb-info.txt")"
test "${#final_digest}" -eq 64
test "$final_digest" != "$STOCK_TOP_VBMETA_DIGEST"
printf 'locked/green top-vbmeta digest mismatch: stock=%s development=%s\n' \
    "$STOCK_TOP_VBMETA_DIGEST" "$final_digest"

mkdir -p "$SCRATCH/image" "$SCRATCH/platform" "$SCRATCH/recovery"
python3 "$UNPACK_BOOTIMG" \
    --boot_img "$IMAGE" \
    --out "$SCRATCH/image" \
    --format=info | tee "$SCRATCH/vendor_boot-info.txt"

python3 - "$IMAGE" "$platform_size" "$recovery_size" "$raw_size" <<'PY'
import struct
import sys

image, platform_size, recovery_size, raw_size = sys.argv[1:]
platform_size = int(platform_size)
recovery_size = int(recovery_size)
raw_size = int(raw_size)
with open(image, "rb") as stream:
    data = stream.read(raw_size)

def u32(offset):
    return struct.unpack_from("<I", data, offset)[0]

def align(value, page=4096):
    return (value + page - 1) // page * page

assert data[:8] == b"VNDRBOOT"
assert u32(8) == 4
assert u32(12) == 4096
assert u32(16) == 0x80000000
assert u32(20) == 0xA6F00000
assert u32(24) == platform_size + recovery_size
assert data[28:2076].split(b"\0", 1)[0] == b"bootopt=64S3,32N2,64N2 erofs.reserved_pages=64"
assert u32(2076) == 0x87C80000
assert data[2080:2096].rstrip(b"\0") == b""
assert u32(2096) == 2128
assert u32(2100) == 532322
assert struct.unpack_from("<Q", data, 2104)[0] == 0x87C80000
assert u32(2112) == 216
assert u32(2116) == 2
assert u32(2120) == 108
assert u32(2124) == 0

table_offset = align(2128) + align(platform_size + recovery_size) + align(532322)
entry_format = "<III32s16I"
entry0 = struct.unpack_from(entry_format, data, table_offset)
entry1 = struct.unpack_from(entry_format, data, table_offset + 108)
assert entry0[0:3] == (platform_size, 0, 1)
assert entry0[3].rstrip(b"\0") == b""
assert all(value == 0 for value in entry0[4:])
assert entry1[0:3] == (recovery_size, platform_size, 2)
assert entry1[3].rstrip(b"\0") == b"recovery"
assert all(value == 0 for value in entry1[4:])
expected_raw = align(2128) + align(platform_size + recovery_size) + align(532322) + align(216)
assert raw_size == expected_raw
print(f"v4-header-table-contract: entries=2 raw={raw_size} platform={platform_size} recovery={recovery_size}")
PY

cmp "$SCRATCH/image/vendor-ramdisk-by-name/ramdisk_" "$PLATFORM"
cmp "$SCRATCH/image/vendor-ramdisk-by-name/ramdisk_recovery" "$RECOVERY"
cmp "$SCRATCH/image/dtb" "$DTB"

"$LZ4" -dc "$PLATFORM" | (
    cd "$SCRATCH/platform"
    cpio --quiet -idmu --no-absolute-filenames
)
"$LZ4" -dc "$RECOVERY" | (
    cd "$SCRATCH/recovery"
    cpio --quiet -idmu --no-absolute-filenames
)

printf '%s\n' '=== stock platform preservation ==='
assert_sha256 "$EXPECTED_DRM_SHA256" "$SCRATCH/platform/lib/modules/mediatek-drm.ko"
assert_sha256 "$EXPECTED_PANEL_SHA256" "$SCRATCH/platform/lib/modules/panel-o12-42-02-0a-dsc-cmd.ko"
assert_sha256 "$EXPECTED_MODULES_LOAD_SHA256" "$SCRATCH/platform/lib/modules/modules.load.recovery"
assert_sha256 "$EXPECTED_MODULES_DEP_SHA256" "$SCRATCH/platform/lib/modules/modules.dep"
assert_sha256 "$EXPECTED_BOOT_HAL_SHA256" \
    "$SCRATCH/platform/system/bin/hw/android.hardware.boot-service.mtk_recovery"
assert_sha256 "$EXPECTED_HEALTH_HAL_SHA256" \
    "$SCRATCH/platform/system/bin/hw/android.hardware.health-service.example_recovery"
assert_sha256 "$EXPECTED_FASTBOOT_HAL_SHA256" \
    "$SCRATCH/platform/system/lib64/hw/android.hardware.fastboot@1.0-impl-mtk.so"
assert_sha256 "$EXPECTED_MTK_BSG_SHA256" "$SCRATCH/platform/system/lib64/libmtk_bsg.so"
test -s "$SCRATCH/platform/lib/modules/mtk-mml.ko"
test -s "$SCRATCH/platform/lib/modules/irq-dbg.ko"
test -s "$SCRATCH/platform/lib/modules/nxp_i2c.ko"
test -s "$SCRATCH/platform/lib/modules/p73.ko"
grep -F '/lib/modules/p73.ko: /lib/modules/nxp_i2c.ko /lib/modules/spi-mt65xx.ko /lib/modules/irq-dbg.ko' \
    "$SCRATCH/platform/lib/modules/modules.dep"
test -s "$SCRATCH/platform/first_stage_ramdisk/fstab.mt6991"
test -x "$SCRATCH/platform/first_stage_ramdisk/system/bin/snapuserd"
test -s "$SCRATCH/platform/sepolicy"
test ! -e "$SCRATCH/platform/res"
test "$(find "$SCRATCH/platform/lib/modules" -maxdepth 1 -type f -name '*.ko' | wc -l)" -eq 273
test ! -e "$SCRATCH/platform/system/etc/vintf/manifest/android.hardware.boot-service.mtk.xml"
test ! -e "$SCRATCH/platform/system/etc/vintf/manifest/android.hardware.health-service.example.xml"
test "$(find "$SCRATCH/platform/system" -mindepth 1 ! -type d | wc -l)" -eq 26
printf '%s\n' 'stock modules: 273; 2 Dali device VINTF fragments relocated; remaining stock-only system entries: 26; active DRM/panel and MTK HAL hashes matched'

printf '%s\n' '=== recovery AP touch overlay ==='
test "$(find "$SCRATCH/recovery/lib/modules" -maxdepth 1 -type f -name '*.ko' | wc -l)" -eq 3
assert_sha256 "$EXPECTED_SCP_SHA256" "$SCRATCH/recovery/lib/modules/scp.ko"
assert_sha256 "$EXPECTED_GOODIX_SHA256" \
    "$SCRATCH/recovery/lib/modules/goodix_core_dali.ko"
assert_sha256 "$EXPECTED_XIAOMI_TOUCH_SHA256" \
    "$SCRATCH/recovery/lib/modules/xiaomi_touch_dali.ko"
cmp "$RECOVERY_MODULES/scp.ko" "$SCRATCH/recovery/lib/modules/scp.ko"
cmp "$RECOVERY_MODULES/goodix_core_dali.ko" \
    "$SCRATCH/recovery/lib/modules/goodix_core_dali.ko"
cmp "$RECOVERY_MODULES/xiaomi_touch_dali.ko" \
    "$SCRATCH/recovery/lib/modules/xiaomi_touch_dali.ko"
test ! -e "$SCRATCH/recovery/lib/firmware/goodix_cfg_group_dali.bin"
test ! -e "$SCRATCH/recovery/lib/firmware/goodix_firmware_dali.bin"
test ! -e "$SCRATCH/recovery/FFiles"
test "$(grep -Fxc '/lib/modules/xiaomi_touch_dali.ko: /lib/modules/mediatek-drm.ko /lib/modules/miev.ko' \
    "$SCRATCH/recovery/lib/modules/modules.dep")" -eq 1
test "$(grep -Fxc '/lib/modules/scp.ko: /lib/modules/mtk_tinysys_ipi.ko /lib/modules/mtk_rpmsg_mbox.ko /lib/modules/mtk-mbox.ko /lib/modules/clk-common.ko /lib/modules/mtk-afe-external.ko /lib/modules/aee_aed.ko' \
    "$SCRATCH/recovery/lib/modules/modules.dep")" -eq 1
test "$(grep -Fxc '/lib/modules/goodix_core_dali.ko: /lib/modules/tui-common.ko /lib/modules/mtk_tinysys_ipi.ko /lib/modules/spi-mt65xx.ko /lib/modules/scp.ko /lib/modules/xiaomi_touch_dali.ko' \
    "$SCRATCH/recovery/lib/modules/modules.dep")" -eq 1
printf '%s\n' 'Recovery overlay: 3 dali modules; stock-derived dependency map; ODM-only touch firmware'

printf '%s\n' '=== recovery ADB, startup and device config ==='
test -x "$SCRATCH/recovery/system/bin/recovery"
test -x "$SCRATCH/recovery/system/bin/adbd"
test -x "$SCRATCH/recovery/system/bin/fastbootd"
test -x "$SCRATCH/recovery/system/bin/sleep"
test -s "$SCRATCH/recovery/system/bin/beforemodules.sh"
test -s "$SCRATCH/recovery/fstab.recovery.mt6991"
grep -Fx 'odm /odm erofs ro wait,slotselect,logical' \
    "$SCRATCH/recovery/fstab.recovery.mt6991"
grep -Fx 'odm /odm ext4 ro wait,slotselect,logical' \
    "$SCRATCH/recovery/fstab.recovery.mt6991"
cmp "$MINUI_SOURCE" "$SCRATCH/recovery/system/lib64/libminuitwrp.so"
cmp "$KEYSTORE2_SOURCE" "$SCRATCH/recovery/system/bin/keystore2"
cmp "$SE_OMAPI_SOURCE" "$SCRATCH/recovery/system/bin/se_omapi"
printf 'keystore2 source/recovery SHA-256:\n'
sha256sum "$KEYSTORE2_SOURCE" "$SCRATCH/recovery/system/bin/keystore2"
printf 'se_omapi source/recovery SHA-256:\n'
sha256sum "$SE_OMAPI_SOURCE" "$SCRATCH/recovery/system/bin/se_omapi"
grep -aF 'setting DRM_FORMAT_XBGR8888 and GGL_PIXEL_FORMAT_RGBA_8888' \
    "$SCRATCH/recovery/system/lib64/libminuitwrp.so" >/dev/null
grep -aF 'EV_FF haptics: using' \
    "$SCRATCH/recovery/system/lib64/libminuitwrp.so" >/dev/null
grep -aF 'Apex is disabled in this build' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -aF 'TW_INCLUDE_CRYPTO := true' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -aF 'Successfully decrypted metadata encrypted data partition' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -aF 'Keeping /vendor mounted for Recovery vendor libraries' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
test -x "$SCRATCH/recovery/system/bin/keystore2"
test -x "$SCRATCH/recovery/system/bin/se_omapi"
if grep -aEq 'AID=|select response:|ATR:' "$SCRATCH/recovery/system/bin/se_omapi"; then
    echo 'se_omapi contains sensitive payload logging' >&2
    exit 1
fi
test -s "$SCRATCH/recovery/system/lib64/android.se.omapi-V1-ndk.so"
test -s "$SCRATCH/recovery/system/lib64/android.hardware.secure_element-V1-ndk.so"
test -s "$SCRATCH/recovery/system/etc/init/keystore2.rc"
test -s "$SCRATCH/recovery/system/etc/init/se_omapi.rc"
grep -F 'interface aidl android.se.omapi.ISecureElementService/default' \
    "$SCRATCH/recovery/system/etc/init/se_omapi.rc"
cmp "$CRYPTO_KEYSTORE_RC" "$SCRATCH/recovery/system/etc/init/keystore2.rc"
grep -F 'service keystore2 /system/bin/keystore2 /data/misc/keystore' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"
grep -F 'user keystore' "$SCRATCH/recovery/system/etc/init/keystore2.rc"
grep -F 'group keystore readproc log' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"
grep -F 'task_profiles ProcessCapacityHigh' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"
grep -F 'rlimit memlock unlimited unlimited' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"
if grep -Eq '^[[:space:]]*seclabel[[:space:]]' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"; then
    echo 'keystore2 must use the stock domain transition' >&2
    exit 1
fi
grep -F 'disabled' "$SCRATCH/recovery/system/etc/init/keystore2.rc"
if grep -Eq '^on late-init' \
    "$SCRATCH/recovery/system/etc/init/keystore2.rc"; then
    echo 'keystore2 starts before the Dali MITEe dependency chain' >&2
    exit 1
fi
assert_sha256 "$EXPECTED_FRAMEWORK_MANIFEST_SHA256" \
    "$SCRATCH/recovery/system/etc/vintf/manifest.xml"
grep -F 'type="framework"' "$SCRATCH/recovery/system/etc/vintf/manifest.xml"
test ! -e "$SCRATCH/recovery/system/etc/vintf/manifest/android.hardware.boot-service.mtk.xml"
test ! -e "$SCRATCH/recovery/system/etc/vintf/manifest/android.hardware.health-service.example.xml"
assert_sha256 "$EXPECTED_VENDOR_MANIFEST_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest.xml"
grep -F '<name>android.hardware.secure_element</name>' \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest.xml"
grep -F '<fqname>ISecureElement/eSE1</fqname>' \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest.xml"
grep -F '<name>android.se.omapi</name>' \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest.xml"
grep -F '<fqname>ISecureElementService/default</fqname>' \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest.xml"
test ! -e "$SCRATCH/recovery/vendor/etc/vintf/manifest/se_omapi.xml"
assert_sha256 "$EXPECTED_VENDOR_MATRIX_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/compatibility_matrix.xml"
assert_sha256 "$EXPECTED_BOOT_VINTF_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest/android.hardware.boot-service.mtk.xml"
assert_sha256 "$EXPECTED_HEALTH_VINTF_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest/android.hardware.health-service.example.xml"
assert_sha256 "$EXPECTED_KEYMINT_MANIFEST_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.mitee.xml"
assert_sha256 "$EXPECTED_GATEKEEPER_MANIFEST_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest/android.hardware.gatekeeper-service.mitee.xml"
assert_sha256 "$EXPECTED_WEAVER_MANIFEST_SHA256" \
    "$SCRATCH/recovery/vendor/etc/vintf/manifest/android.hardware.weaver-service.nxp.xml"
grep -F '/dev/tee0 u:object_r:mitee_client_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/teepriv0 u:object_r:mitee_client_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/rpmb0 u:object_r:teei_rpmb_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/ufs-bsg0 u:object_r:bsg_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/0:0:0:49476 u:object_r:dali_rpmb_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/p73 u:object_r:nfc_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/dev/block/by-name/persist u:object_r:persist_block_device:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/mnt/vendor/persist(/.*)? u:object_r:persist_data_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/mnt/vendor/persist/data(/.*)? u:object_r:mitee_sfs_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/mnt/vendor/persist/fdsd(/.*)? u:object_r:vendor_persist_drm_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/persist/fdsd(/.*)? u:object_r:vendor_persist_drm_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/data/vendor/mitee(/.*)? u:object_r:mitee_data_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -F '/data/vendor/thh(/.*)? u:object_r:teei_data_file:s0' \
    "$SCRATCH/recovery/vendor_file_contexts"
grep -aF 'Starting MTP' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -aF 'MTP fd' \
    "$SCRATCH/recovery/system/lib64/libtwrpmtp-ffs.so" >/dev/null
grep -n -m1 '^ro.debuggable=1$' "$SCRATCH/recovery/prop.default"
grep -n -m1 '^ro.secure=0$' "$SCRATCH/recovery/prop.default"
grep -n -m1 '^persist.sys.usb.config=adb$' "$SCRATCH/recovery/prop.default"
grep -n -m1 '^ro.minui.pixel_format=RGBX_8888$' "$SCRATCH/recovery/prop.default"
INIT_RC="$SCRATCH/recovery/system/etc/init/hw/init.rc"
grep -nE '^[[:space:]]*service[[:space:]]+adbd /system/bin/adbd' "$INIT_RC"
grep -F 'import /init.recovery.usb.rc' "$INIT_RC"
grep -F 'import /init.recovery.${ro.hardware}.rc' "$INIT_RC"
grep -F 'setprop sys.usb.configfs 1' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'setprop sys.usb.controller "16701000.usb0"' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'on property:twrp.modules.loaded=true' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'wait /odm/mitee/ta 5' "$SCRATCH/recovery/init.recovery.mt6991.rc"
if grep -Fq 'mount_all /fstab.recovery.mt6991 --early' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"; then
    echo 'obsolete ODM remount remains in init' >&2
    exit 1
fi
grep -F '123af5d1-d6f5-cc54-f78fa19030b2e76a.ta' \
    "$SCRATCH/recovery/system/bin/beforemodules.sh"
grep -F 'a3ba6512-6e0e-4065-93165e4a7d04ca08.ta' \
    "$SCRATCH/recovery/system/bin/beforemodules.sh"
grep -F 'a734ee00-d6a1-4244-aa507c99719e7b7f.ta' \
    "$SCRATCH/recovery/system/bin/beforemodules.sh"
grep -F 'd32d9207-6285-6d86-6cb98eaf46f6b4ec.ta' \
    "$SCRATCH/recovery/system/bin/beforemodules.sh"
grep -aF 'Keeping /odm mounted for recovery services' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -F 'service tee-supplicant /vendor/bin/tee-supplicant' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'service vendor.keymint-mitee /vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'service vendor.gatekeeper_mitee /vendor/bin/hw/android.hardware.gatekeeper-service.mitee' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'service vendor.weaver_nxp /vendor/bin/hw/android.hardware.weaver-service.nxp' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'service vendor.secure_element_hal_service /vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon_recursive /mnt/vendor/persist' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon /system/bin/linker64' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon /system/bin/keystore2' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon /system/etc/ld.config.txt' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon_recursive /system/etc/vintf' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon_recursive /vendor/etc/vintf' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start tee-supplicant' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start vendor.keymint-mitee' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start vendor.gatekeeper_mitee' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start vendor.weaver_nxp' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start vendor.secure_element_hal_service' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'start keystore2' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'chmod 0660 /dev/0:0:0:49476' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'chown system system /dev/0:0:0:49476' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'wait /dev/p73 5' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon /dev/p73' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'chmod 0660 /dev/p73' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'chown nfc nfc /dev/p73' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'on property:dali.crypto.tee.requested=1 && property:init.svc.tee-supplicant=running' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'on property:dali.crypto.hals.requested=1 && property:init.svc.vendor.gatekeeper_mitee=running && property:init.svc.vendor.weaver_nxp=running' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'restorecon /system/bin/toybox' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'mkdir /data/vendor 0771 root root' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'mkdir /data/vendor/mitee 0755 system system' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'exec -- /system/bin/toybox sleep 0.25' "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'wait /sys/class/touch/touch_dev/enable_touch_raw 5' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
grep -F 'write /sys/class/touch/touch_dev/enable_touch_raw 0' \
    "$SCRATCH/recovery/init.recovery.mt6991.rc"
BEFOREMODULES="$SCRATCH/recovery/system/bin/beforemodules.sh"
grep -F 'status=/tmp/dali-beforemodules.status' "$BEFOREMODULES"
grep -F 'slot="$(getprop ro.boot.slot_suffix)"' "$BEFOREMODULES"
grep -F 'for block in "/dev/block/mapper/${partition}${slot}"' "$BEFOREMODULES"
grep -F '"/dev/block/by-name/${partition}"; do' "$BEFOREMODULES"
grep -F 'mount -t erofs -o ro "$block" "$target"' "$BEFOREMODULES"
grep -F 'mount -t ext4 -o ro "$block" "$target"' "$BEFOREMODULES"
grep -F 'if mount_partition odm /odm &&' "$BEFOREMODULES"
grep -Fx 'mount_partition vendor /vendor' "$BEFOREMODULES"
grep -Fx 'mount_partition vendor_dlkm /vendor_dlkm' "$BEFOREMODULES"
grep -F 'mount_persist()' "$BEFOREMODULES"
grep -F 'for block in /dev/block/by-name/persist /dev/block/sdc9; do' "$BEFOREMODULES"
grep -F 'mount -t ext4 -o rw,noatime,nosuid,nodev "$block" /persist' "$BEFOREMODULES"
grep -F 'mount -o bind /persist /mnt/vendor/persist' "$BEFOREMODULES"
grep -F 'module_dir=/lib/modules' "$BEFOREMODULES"
grep -F 'modprobe -d "$module_dir" "$module"' "$BEFOREMODULES"
grep -Fx 'load_module p73' "$BEFOREMODULES"
grep -F 'module_dir=/vendor_dlkm/lib/modules' "$BEFOREMODULES"
grep -Fx 'load_module leds-mt6379pmic' "$BEFOREMODULES"
grep -Fx 'load_module cs40l26-i2c' "$BEFOREMODULES"
grep -F 'allow tee nfc_device:chr_file { ioctl read write open };' \
    "$CRYPTO_DEVICE_POLICY"
grep -F 'allow hal_secure_element_default mitee_client_device:chr_file { ioctl read write getattr lock append map open watch watch_reads };' \
    "$CRYPTO_DEVICE_POLICY"
grep -F 'firmware:cs40l26:present' "$BEFOREMODULES"
grep -F 'module:${module}:loaded' "$BEFOREMODULES"
if grep -F 'load_module leds-mt6379' "$BEFOREMODULES" | \
    grep -Fvx 'load_module leds-mt6379pmic' >/dev/null; then
    echo 'non-PMIC MT6379 flashlight target selected' >&2
    exit 1
fi
grep -F 'mkdir /config/usb_gadget/g1/functions/ffs.mtp' \
    "$SCRATCH/recovery/init.recovery.usb.rc"
grep -F 'mount functionfs mtp /dev/usb-ffs/mtp' \
    "$SCRATCH/recovery/init.recovery.usb.rc"
grep -F 'sys.usb.ffs.mtp.ready=1' \
    "$SCRATCH/recovery/init.recovery.usb.rc"
grep -F 'write /config/usb_gadget/g1/idProduct 0x4EE2' \
    "$SCRATCH/recovery/init.recovery.usb.rc"
grep -F '/devices/platform/soc/16701000.usb0/16700000.xhci0/usb* /usb_otg auto defaults voldmanaged=usb:auto' \
    "$SCRATCH/recovery/system/etc/recovery.fstab"
cmp "$SCRATCH/recovery/system/etc/recovery.fstab" "$DEVICE/recovery.fstab"
cmp "$SCRATCH/recovery/first_stage_ramdisk/fstab.mt6991" \
    "$DEVICE/recovery/root/first_stage_ramdisk/fstab.mt6991"

printf '%s\n' '=== final twres geometry and retired flows ==='
TWRES="$SCRATCH/recovery/twres"
test -d "$TWRES"
grep -F '<resolution width="1080" height="1920" />' "$TWRES/ui.xml" >/dev/null
grep -F '<variable name="status_left_x" value="%status_indent_left%"/>' \
    "$TWRES/resources/vars.xml" >/dev/null
grep -F '<variable name="status_right_x" value="%screen_w%-%status_indent_right%"/>' \
    "$TWRES/resources/vars.xml" >/dev/null
grep -F '<placement x="%status_left_x%" y="%status_info_y%"/>' \
    "$TWRES/pages/templates/statusbar.xml" >/dev/null
grep -F '<placement x="%status_right_x%" y="%status_info_y%" placement="1"/>' \
    "$TWRES/pages/templates/statusbar.xml" >/dev/null
grep -F 'DEVICE_RESOLUTION := 1280x2772' "$DEVICE/BoardConfig.mk" >/dev/null
for needle in \
    "OF_SCREEN_H='\\\"1920\\\"'" \
    "OF_STATUS_H='\\\"105\\\"'" \
    "OF_STATUS_INDENT_LEFT='\\\"81\\\"'" \
    "OF_STATUS_INDENT_RIGHT='\\\"81\\\"'"; do
    grep -F -- "$needle" "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
done
test -s "$TWRES/images/Default/About/card.png"
test -s "$TWRES/images/Default/About/maintainer.png"
grep -F '<image name="card" filename="Default/About/card"/>' \
    "$TWRES/resources/images.xml" >/dev/null
grep -F '<image name="maintainer_img" filename="Default/About/maintainer"/>' \
    "$TWRES/resources/images.xml" >/dev/null
awk '
    /<image resource="maintainer_img"\/>/ { maintainer = NR }
    maintainer && /<image resource="card"\/>/ { mask = NR; exit }
    END { exit !(maintainer && mask > maintainer) }
' "$TWRES/pages/settings.xml"
assert_not_reachable() {
    local token="$1" xml hits
    for xml in "$TWRES"/pages/*.xml "$TWRES"/pages/templates/*.xml; do
        hits="$(xmllint --xpath \
            "count(//page[@name='$token'] | //action[contains(normalize-space(.), '$token')])" \
            "$xml")"
        test "$hits" = 0
    done
}
for token in FFiles fox_modules fox_modules_confirm mod_survival \
    dialog_lost_info dialog_app dialog_magisk_not_found; do
    assert_not_reachable "$token"
done

grep -Eq '^vendor_dlkm[[:space:]]+/vendor_dlkm.*slotselect,logical' \
    "$SCRATCH/recovery/system/etc/recovery.fstab"
grep -aF '/vendor_dlkm/lib/modules' "$SCRATCH/recovery/system/bin/recovery" >/dev/null
grep -aF 'goodix_core_dali.ko' "$SCRATCH/recovery/system/bin/recovery" >/dev/null
printf '%s\n' 'module loader: merged vendor_boot /lib/modules; Goodix request resolves the AP-only dali dependency chain'

printf '%s\n' '=== compiled touch and display settings ==='
grep -F 'TW_LOAD_VENDOR_MODULES=\"goodix_core_dali.ko\"' \
    "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F -m1 -- '-DTW_INCLUDE_CRYPTO' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F -m1 -- '-DTW_HAS_MTP' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F -m1 -- '-DUSE_VENDOR_LIBS=1' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F -m1 -- '-DTW_KEEP_ODM_MOUNTED' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F -m1 -- '-DTW_LOAD_VENDOR_BOOT_MODULES' \
    "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F 'TW_BRIGHTNESS_PATH=\"/sys/class/leds/lcd-backlight/brightness\"' \
    "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F 'TW_MAX_BRIGHTNESS=16383' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F 'TW_DEFAULT_BRIGHTNESS=1228' "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -Fx 'OF_FLASHLIGHT_ENABLE := 1' "$DEVICE/fox_dali.mk"
grep -Fx 'OF_FL_PATH1 := /sys/class/leds/white:flash-1' "$DEVICE/fox_dali.mk"
if grep -Eq '^OF_FL_PATH2[[:space:]]*:=' "$DEVICE/fox_dali.mk"; then
    echo 'a second flashlight path is configured for dali' >&2
    exit 1
fi
grep -F "OF_FLASHLIGHT_ENABLE='\\\"1\\\"'" \
    "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -F "OF_FL_PATH1='\\\"/sys/class/leds/white:flash-1\\\"'" \
    "$OUT_BASE/build-twrp_dali.ninja" >/dev/null
grep -aF '/sys/class/leds/white:flash-1' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null
if grep -aE '/sys/class/leds/white:flash-[23]' \
    "$SCRATCH/recovery/system/bin/recovery" >/dev/null; then
    echo 'an unselected dali flashlight path is compiled into recovery' >&2
    exit 1
fi
grep -F -m1 -- '-DTW_FRAMERATE=60' "${SOONG_NINJAS[@]}" >/dev/null
grep -F -m1 -- '-DTW_ROTATION=0' "${SOONG_NINJAS[@]}" >/dev/null
grep -F -m1 -- '-DRECOVERY_RGBX' "${SOONG_NINJAS[@]}" >/dev/null
printf '%s\n' \
    'touch bootstrap: dali AP-only SCP/Goodix modules plus stock Xiaomi framework' \
    'firmware source: beforemodules.sh mounts logical ODM read-only before Goodix probe' \
    'feature modules: active-slot vendor/vendor_dlkm provide MT6379 flashlight and CS40L26 haptics' \
    'flashlight: /sys/class/leds/white:flash-1; max 75; device-tested at brightness 30' \
    'FBE: recovery keystore2 with MITEe KeyMint/Gatekeeper and NXP Weaver; /vendor remains mounted' \
    'touch mode: twrp.modules.loaded -> wait -> Goodix raw-disable/coordinate-enable' \
    'pixel format: RGBX_8888 (DRM XBGR8888); UI frame rate: 60; rotation: 0' \
    'brightness: /sys/class/leds/lcd-backlight/brightness; max 16383; default 1228'

printf '%s\n' '=== optional files excluded by measured capacity ==='
for path in \
    sbin/ksud sbin/bash sbin/zip sbin/zstd sbin/lz4 \
    system/bin/nano system/etc/nano system/etc/terminfo \
    system/lib64/libncurses.so FFiles; do
    test ! -e "$SCRATCH/recovery/$path"
done

printf '%s\n' '=== final sizes and SHA-256 ==='
stat -c '%n %s bytes' "$IMAGE" "$RAW" "$PLATFORM" "$RECOVERY"
sha256sum "$IMAGE" "$RAW" "$PLATFORM" "$RECOVERY" "$DTB"
printf '%s\n' 'VERIFY_DALI_VENDOR_BOOT_STRUCTURE_OK'
