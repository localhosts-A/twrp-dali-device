#!/usr/bin/env bash
set -euo pipefail

EXPECTED_PLATFORM_SHA256=df9110b7efd59f053485dc4117e9907c8edc35d44cece79f15057d2f32751555
EXPECTED_DTB_SHA256=223984cc1daf6f9194ff33e4c674dce9f2de9203dc9b73e72bd1e0754dbf4ae4
EXPECTED_SCP_SHA256=3aa2d9c09af01935149f348ff853c3f7069993d92e89892d32b92e8c8c49a392
EXPECTED_GOODIX_SHA256=1b07da57b40a16cc4dd3b221010c05e30df35c3ce8fecae05f9d91d09a496bd6
EXPECTED_XIAOMI_TOUCH_SHA256=115197fb99c2a56b9fc6111da3b4c1a323fd80e197b768253276e2f518674b20
AVB_SALT=2db181f89cbfa19a432e02b260bc991097e8918da9f254461228ee6a2b264db8
STOCK_TOP_VBMETA_DIGEST=75254351fb4c27ccb69d60eab1c9aabf09de9abb791c7665137eca99241c87be
PARTITION_SIZE=67108864
MAX_FOOTER_INPUT_SIZE=67039232

TOP="${ANDROID_BUILD_TOP:-$(pwd)}"
OUT_BASE="${OUT_DIR:-out}"
[[ "$OUT_BASE" = /* ]] || OUT_BASE="$TOP/$OUT_BASE"
PRODUCT_OUT="${ANDROID_PRODUCT_OUT:-$OUT_BASE/target/product/dali}"
[[ "$PRODUCT_OUT" = /* ]] || PRODUCT_OUT="$TOP/$PRODUCT_OUT"

DEVICE="$TOP/device/xiaomi/dali"
CRYPTO_VINTF="$DEVICE/prebuilt/crypto_vintf"
CRYPTO_VINTF_VENDOR="$CRYPTO_VINTF/vendor"
CRYPTO_KEYSTORE_RC="$DEVICE/recovery/root/system/etc/init/keystore2.rc"
CRYPTO_DEVICE_POLICY="$DEVICE/sepolicy/vendor/crypto_devices.te"
PLATFORM_PREBUILT="$DEVICE/prebuilt/vendor_ramdisk_platform.lz4"
DTB="$DEVICE/prebuilt/dtb/mt6991-stock.dtb"
RECOVERY_MODULES="$DEVICE/prebuilt/recovery_modules"
RECOVERY_SOURCE="$PRODUCT_OUT/recovery/root"
DEVICE_RECOVERY_ROOT="$DEVICE/recovery/root"
DEVICE_RECOVERY_FSTAB="$DEVICE/recovery.fstab"
MINUI_SOURCE="$PRODUCT_OUT/system/lib64/libminuitwrp.so"
KEYSTORE2_SOURCE="$PRODUCT_OUT/system/bin/keystore2"
SE_OMAPI_SOURCE="$PRODUCT_OUT/system/bin/se_omapi"
MAIN_VENDOR_RAMDISK="$PRODUCT_OUT/obj/PACKAGING/vendor_boot_intermediates/vendor_ramdisk.cpio.gz"
HOST_BIN="$OUT_BASE/host/linux-x86/bin"
MKBOOTFS="$HOST_BIN/mkbootfs"
LZ4="$HOST_BIN/lz4"
MKBOOTIMG="$HOST_BIN/mkbootimg"
AVBTOOL="$TOP/external/avb/avbtool.py"
UNPACK_BOOTIMG="$TOP/system/tools/mkbootimg/unpack_bootimg.py"
DEPLOY_OUT="$PRODUCT_OUT/dali-deploy"
SCRATCH="$(mktemp -d "$OUT_BASE/dali-vendorboot.XXXXXX")"

case "$SCRATCH" in
    "$OUT_BASE"/dali-vendorboot.*) ;;
    *) exit 2 ;;
esac

cleanup() {
    rm -rf -- "$SCRATCH"
}
trap cleanup EXIT

for file in "$PLATFORM_PREBUILT" "$DTB" "$MINUI_SOURCE" "$KEYSTORE2_SOURCE" "$SE_OMAPI_SOURCE" "$MAIN_VENDOR_RAMDISK" \
    "$CRYPTO_VINTF/SHA256SUMS" \
    "$CRYPTO_VINTF/framework_manifest.xml" \
    "$CRYPTO_VINTF/vendor_file_contexts" \
    "$CRYPTO_VINTF_VENDOR/manifest.xml" \
    "$CRYPTO_VINTF_VENDOR/compatibility_matrix.xml" \
    "$CRYPTO_KEYSTORE_RC" \
    "$CRYPTO_DEVICE_POLICY" \
    "$RECOVERY_MODULES/scp.ko" \
    "$RECOVERY_MODULES/goodix_core_dali.ko" \
    "$RECOVERY_MODULES/xiaomi_touch_dali.ko" \
    "$MKBOOTFS" "$LZ4" "$MKBOOTIMG" \
    "$AVBTOOL" "$UNPACK_BOOTIMG"; do
    test -s "$file"
done
test -d "$RECOVERY_SOURCE"
test -d "$DEVICE_RECOVERY_ROOT"
test -s "$DEVICE_RECOVERY_FSTAB"
command -v cpio >/dev/null

platform_hash="$(sha256sum "$PLATFORM_PREBUILT" | awk '{print $1}')"
dtb_hash="$(sha256sum "$DTB" | awk '{print $1}')"
test "$platform_hash" = "$EXPECTED_PLATFORM_SHA256"
test "$dtb_hash" = "$EXPECTED_DTB_SHA256"
test "$(sha256sum "$RECOVERY_MODULES/scp.ko" | awk '{print $1}')" = "$EXPECTED_SCP_SHA256"
test "$(sha256sum "$RECOVERY_MODULES/goodix_core_dali.ko" | awk '{print $1}')" = "$EXPECTED_GOODIX_SHA256"
test "$(sha256sum "$RECOVERY_MODULES/xiaomi_touch_dali.ko" | awk '{print $1}')" = "$EXPECTED_XIAOMI_TOUCH_SHA256"

PLATFORM_ROOT="$SCRATCH/platform-root"
RECOVERY_ROOT="$SCRATCH/recovery-root"
mkdir -p "$PLATFORM_ROOT" "$RECOVERY_ROOT" "$DEPLOY_OUT"

"$LZ4" -dc "$PLATFORM_PREBUILT" >"$SCRATCH/platform-stock.cpio"
(
    cd "$PLATFORM_ROOT"
    cpio --quiet -idmu --no-absolute-filenames <"$SCRATCH/platform-stock.cpio"
)
cp -a "$RECOVERY_SOURCE/." "$RECOVERY_ROOT/"
# Overlay device-owned static init files after the generated recovery staging
# tree; the build can reuse an older output directory between invocations.
cp -a "$DEVICE_RECOVERY_ROOT/." "$RECOVERY_ROOT/"
install -D -m 0644 "$DEVICE_RECOVERY_FSTAB" \
    "$RECOVERY_ROOT/system/etc/recovery.fstab"
# The exact stock Dali manifest installed below already declares both eSE1 and
# OMAPI/default. Drop OrangeFox's generic fragment to avoid a duplicate FQName.
rm -f -- "$RECOVERY_ROOT/vendor/etc/vintf/manifest/se_omapi.xml"

# ServiceManager and ueventd start before beforemodules.sh can mount the live
# vendor partition. Package only the exact VINTF and file-context inputs
# captured from this Dali so their early snapshots match the later /vendor
# mount. The dynamic vendor partition replaces this directory afterwards.
(
    cd "$CRYPTO_VINTF"
    sha256sum -c SHA256SUMS
)
mkdir -p \
    "$RECOVERY_ROOT/system/etc/vintf" \
    "$RECOVERY_ROOT/system/etc/init" \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest"
install -m 0644 "$CRYPTO_VINTF/framework_manifest.xml" \
    "$RECOVERY_ROOT/system/etc/vintf/manifest.xml"
# The stock PLATFORM fragment contributes two device manifests beneath the
# framework directory after the vendor-ramdisk fragments are merged. Use the
# exact copies captured from Dali vendor as device fragments, and remove the
# misplaced PLATFORM/Recovery copies before either CPIO is rebuilt.
for fragment in \
    android.hardware.boot-service.mtk.xml \
    android.hardware.health-service.example.xml; do
    test -s "$PLATFORM_ROOT/system/etc/vintf/manifest/$fragment"
    rm -f -- "$PLATFORM_ROOT/system/etc/vintf/manifest/$fragment"
    rm -f -- "$RECOVERY_ROOT/system/etc/vintf/manifest/$fragment"
done
# Device manifests are installed by the vendor-fragment loop below.
install -m 0644 "$CRYPTO_KEYSTORE_RC" \
    "$RECOVERY_ROOT/system/etc/init/keystore2.rc"
install -m 0644 "$CRYPTO_VINTF_VENDOR/manifest.xml" \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml"
install -m 0644 "$CRYPTO_VINTF_VENDOR/compatibility_matrix.xml" \
    "$RECOVERY_ROOT/vendor/etc/vintf/compatibility_matrix.xml"
for fragment in "$CRYPTO_VINTF_VENDOR"/manifest/*.xml; do
    install -m 0644 "$fragment" "$RECOVERY_ROOT/vendor/etc/vintf/manifest/"
done

# Keep the stock PLATFORM fragment intact except for the two VINTF fragments
# relocated above. Recovery overlays only this device's three touch modules and
# a dependency map based on the stock map. Touch firmware is deliberately not
# copied into Recovery: the measured ODM firmware is the sole source.
mkdir -p "$RECOVERY_ROOT/lib/modules"
install -m 0644 "$RECOVERY_MODULES/scp.ko" "$RECOVERY_ROOT/lib/modules/scp.ko"
install -m 0644 "$RECOVERY_MODULES/goodix_core_dali.ko" \
    "$RECOVERY_ROOT/lib/modules/goodix_core_dali.ko"
install -m 0644 "$RECOVERY_MODULES/xiaomi_touch_dali.ko" \
    "$RECOVERY_ROOT/lib/modules/xiaomi_touch_dali.ko"

cp -f "$PLATFORM_ROOT/lib/modules/modules.dep" \
    "$RECOVERY_ROOT/lib/modules/modules.dep"
sed -i -E '\#^/lib/modules/(scp|goodix_core_dali|xiaomi_touch_dali)\.ko:#d' \
    "$RECOVERY_ROOT/lib/modules/modules.dep"
cat >>"$RECOVERY_ROOT/lib/modules/modules.dep" <<'EOF'
/lib/modules/xiaomi_touch_dali.ko: /lib/modules/mediatek-drm.ko /lib/modules/miev.ko
/lib/modules/scp.ko: /lib/modules/mtk_tinysys_ipi.ko /lib/modules/mtk_rpmsg_mbox.ko /lib/modules/mtk-mbox.ko /lib/modules/clk-common.ko /lib/modules/mtk-afe-external.ko /lib/modules/aee_aed.ko
/lib/modules/goodix_core_dali.ko: /lib/modules/tui-common.ko /lib/modules/mtk_tinysys_ipi.ko /lib/modules/spi-mt65xx.ko /lib/modules/scp.ko /lib/modules/xiaomi_touch_dali.ko
EOF

cmp "$RECOVERY_MODULES/scp.ko" "$RECOVERY_ROOT/lib/modules/scp.ko"
cmp "$RECOVERY_MODULES/goodix_core_dali.ko" \
    "$RECOVERY_ROOT/lib/modules/goodix_core_dali.ko"
cmp "$RECOVERY_MODULES/xiaomi_touch_dali.ko" \
    "$RECOVERY_ROOT/lib/modules/xiaomi_touch_dali.ko"

# The recovery root is staged before all modules are rebuilt. Refresh Keystore2
# explicitly so a diagnostic or crypto fix cannot be hidden by a stale copy.
install -m 0755 "$KEYSTORE2_SOURCE" "$RECOVERY_ROOT/system/bin/keystore2"
cmp "$KEYSTORE2_SOURCE" "$RECOVERY_ROOT/system/bin/keystore2"
install -m 0755 "$SE_OMAPI_SOURCE" "$RECOVERY_ROOT/system/bin/se_omapi"
cmp "$SE_OMAPI_SOURCE" "$RECOVERY_ROOT/system/bin/se_omapi"

# The legacy relink_libraries phony target does not refresh this staged file on
# every incremental build. Always take the just-built library so a BoardConfig
# pixel-format change cannot be repacked with the previous libminuitwrp.
grep -aF 'setting DRM_FORMAT_XBGR8888 and GGL_PIXEL_FORMAT_RGBA_8888' \
    "$MINUI_SOURCE" >/dev/null
grep -aF 'EV_FF haptics: using' "$MINUI_SOURCE" >/dev/null
cp -f "$MINUI_SOURCE" "$RECOVERY_ROOT/system/lib64/libminuitwrp.so"
cmp "$MINUI_SOURCE" "$RECOVERY_ROOT/system/lib64/libminuitwrp.so"

# OrangeFox replaces the stock recovery resources. Within system/, discard only
# paths supplied by OrangeFox and retain stock-only MTK recovery HALs and tools.
rm -rf -- "$PLATFORM_ROOT/res"
while IFS= read -r -d '' stock_path; do
    relative="${stock_path#"$PLATFORM_ROOT"/}"
    if [[ -e "$RECOVERY_ROOT/$relative" || -L "$RECOVERY_ROOT/$relative" ]]; then
        rm -f -- "$stock_path"
    fi
done < <(find "$PLATFORM_ROOT/system" -mindepth 1 ! -type d -print0)
find "$PLATFORM_ROOT/system" -depth -type d -empty -delete

# Preserve the generated Virtual A/B first-stage snapuserd payload that AOSP
# normally places in the main anonymous PLATFORM ramdisk.
gzip -t "$MAIN_VENDOR_RAMDISK"
gzip -dc "$MAIN_VENDOR_RAMDISK" >"$SCRATCH/platform-generated.cpio"
(
    cd "$PLATFORM_ROOT"
    cpio --quiet -idmu --no-absolute-filenames <"$SCRATCH/platform-generated.cpio"
)

# Defense in depth for builds made with stale shell exports. These are optional
# OrangeFox console/root addons and are not part of this device's boot contract.
rm -f -- \
    "$RECOVERY_ROOT/sbin/ksud" \
    "$RECOVERY_ROOT/sbin/bash" \
    "$RECOVERY_ROOT/sbin/zip" \
    "$RECOVERY_ROOT/sbin/zstd" \
    "$RECOVERY_ROOT/sbin/lz4" \
    "$RECOVERY_ROOT/system/bin/nano"
rm -rf -- \
    "$RECOVERY_ROOT/FFiles" \
    "$RECOVERY_ROOT/system/etc/nano" \
    "$RECOVERY_ROOT/FFiles/nano"
find "$RECOVERY_ROOT/system/etc/init" -maxdepth 1 -type f -name 'nano*' -delete 2>/dev/null || true

test -s "$PLATFORM_ROOT/lib/modules/mediatek-drm.ko"
test -s "$PLATFORM_ROOT/lib/modules/panel-o12-42-02-0a-dsc-cmd.ko"
for module in aee_aed clk-common irq-dbg mediatek-drm miev mtk-afe-external \
    mtk-mbox mtk_rpmsg_mbox mtk_tinysys_ipi nxp_i2c p73 spi-mt65xx tui-common; do
    test -s "$PLATFORM_ROOT/lib/modules/$module.ko"
done
test -s "$PLATFORM_ROOT/first_stage_ramdisk/fstab.mt6991"
test -x "$PLATFORM_ROOT/first_stage_ramdisk/system/bin/snapuserd"
test -s "$PLATFORM_ROOT/sepolicy"
test -x "$PLATFORM_ROOT/system/bin/hw/android.hardware.boot-service.mtk_recovery"
test -x "$PLATFORM_ROOT/system/bin/hw/android.hardware.health-service.example_recovery"
test -s "$PLATFORM_ROOT/system/lib64/hw/android.hardware.fastboot@1.0-impl-mtk.so"
test -s "$PLATFORM_ROOT/system/lib64/libmtk_bsg.so"
test -x "$RECOVERY_ROOT/system/bin/recovery"
test -x "$RECOVERY_ROOT/system/bin/adbd"
test -x "$RECOVERY_ROOT/system/bin/fastbootd"
test -x "$RECOVERY_ROOT/system/bin/sleep"
test -x "$RECOVERY_ROOT/system/bin/keystore2"
test -x "$RECOVERY_ROOT/system/bin/se_omapi"
if grep -aEq 'AID=|select response:|ATR:' "$RECOVERY_ROOT/system/bin/se_omapi"; then
    echo 'se_omapi contains sensitive payload logging' >&2
    exit 1
fi
test -s "$RECOVERY_ROOT/system/lib64/android.se.omapi-V1-ndk.so"
test -s "$RECOVERY_ROOT/system/lib64/android.hardware.secure_element-V1-ndk.so"
test -s "$RECOVERY_ROOT/system/etc/init/keystore2.rc"
test -s "$RECOVERY_ROOT/system/etc/init/se_omapi.rc"
grep -F 'interface aidl android.se.omapi.ISecureElementService/default' \
    "$RECOVERY_ROOT/system/etc/init/se_omapi.rc" >/dev/null
cmp "$CRYPTO_KEYSTORE_RC" "$RECOVERY_ROOT/system/etc/init/keystore2.rc"
cmp "$CRYPTO_VINTF/framework_manifest.xml" \
    "$RECOVERY_ROOT/system/etc/vintf/manifest.xml"
test ! -e "$RECOVERY_ROOT/system/etc/vintf/manifest/android.hardware.boot-service.mtk.xml"
test ! -e "$RECOVERY_ROOT/system/etc/vintf/manifest/android.hardware.health-service.example.xml"
test ! -e "$PLATFORM_ROOT/system/etc/vintf/manifest/android.hardware.boot-service.mtk.xml"
test ! -e "$PLATFORM_ROOT/system/etc/vintf/manifest/android.hardware.health-service.example.xml"
cmp "$CRYPTO_VINTF_VENDOR/manifest.xml" \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml"
grep -F '<name>android.hardware.secure_element</name>' \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml" >/dev/null
grep -F '<fqname>ISecureElement/eSE1</fqname>' \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml" >/dev/null
grep -F '<name>android.se.omapi</name>' \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml" >/dev/null
grep -F '<fqname>ISecureElementService/default</fqname>' \
    "$RECOVERY_ROOT/vendor/etc/vintf/manifest.xml" >/dev/null
test ! -e "$RECOVERY_ROOT/vendor/etc/vintf/manifest/se_omapi.xml"
cmp "$CRYPTO_VINTF_VENDOR/compatibility_matrix.xml" \
    "$RECOVERY_ROOT/vendor/etc/vintf/compatibility_matrix.xml"
for fragment in "$CRYPTO_VINTF_VENDOR"/manifest/*.xml; do
    cmp "$fragment" "$RECOVERY_ROOT/vendor/etc/vintf/manifest/$(basename "$fragment")"
done
test -s "$RECOVERY_ROOT/vendor_file_contexts"
grep -F '/dev/tee0 u:object_r:mitee_client_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/teepriv0 u:object_r:mitee_client_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/rpmb0 u:object_r:teei_rpmb_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/ufs-bsg0 u:object_r:bsg_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/0:0:0:49476 u:object_r:dali_rpmb_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/p73 u:object_r:nfc_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/dev/block/by-name/persist u:object_r:persist_block_device:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/mnt/vendor/persist(/.*)? u:object_r:persist_data_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/mnt/vendor/persist/data(/.*)? u:object_r:mitee_sfs_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/mnt/vendor/persist/fdsd(/.*)? u:object_r:vendor_persist_drm_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/persist/fdsd(/.*)? u:object_r:vendor_persist_drm_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/data/vendor/mitee(/.*)? u:object_r:mitee_data_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
grep -F '/data/vendor/thh(/.*)? u:object_r:teei_data_file:s0' \
    "$RECOVERY_ROOT/vendor_file_contexts" >/dev/null
test -s "$RECOVERY_ROOT/system/bin/beforemodules.sh"
test -s "$RECOVERY_ROOT/init.recovery.mt6991.rc"
test -s "$RECOVERY_ROOT/init.recovery.usb.rc"
grep -F 'service tee-supplicant /vendor/bin/tee-supplicant' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'service vendor.keymint-mitee /vendor/bin/hw/android.hardware.security.keymint@3.0-service.mitee' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'service vendor.gatekeeper_mitee /vendor/bin/hw/android.hardware.gatekeeper-service.mitee' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'service vendor.weaver_nxp /vendor/bin/hw/android.hardware.weaver-service.nxp' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'service vendor.secure_element_hal_service /vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'wait /dev/p73 5' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon /dev/p73' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'chmod 0660 /dev/p73' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'chown nfc nfc /dev/p73' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'start vendor.secure_element_hal_service' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'chmod 0660 /dev/0:0:0:49476' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'chown system system /dev/0:0:0:49476' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'on property:dali.crypto.tee.requested=1 && property:init.svc.tee-supplicant=running' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'on property:dali.crypto.hals.requested=1 && property:init.svc.vendor.gatekeeper_mitee=running && property:init.svc.vendor.weaver_nxp=running' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon /system/bin/toybox' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'mkdir /data/vendor 0771 root root' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'mkdir /data/vendor/mitee 0755 system system' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'exec -- /system/bin/toybox sleep 0.25' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon_recursive /mnt/vendor/persist' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon /system/bin/linker64' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon /system/bin/keystore2' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon /system/etc/ld.config.txt' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'restorecon_recursive /vendor/etc/vintf' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'start keystore2' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F '16701000.usb0' "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
grep -F 'on property:twrp.modules.loaded=true' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
if grep -Fq 'mount_all /fstab.recovery.mt6991 --early' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc"; then
    echo 'obsolete ODM remount remains in init' >&2
    exit 1
fi
grep -F 'write /sys/class/touch/touch_dev/enable_touch_raw 0' \
    "$RECOVERY_ROOT/init.recovery.mt6991.rc" >/dev/null
BEFOREMODULES="$RECOVERY_ROOT/system/bin/beforemodules.sh"
grep -F 'mount -t erofs -o ro "$block" "$target"' "$BEFOREMODULES" >/dev/null
grep -F 'if mount_partition odm /odm &&' "$BEFOREMODULES" >/dev/null
for ta in \
    123af5d1-d6f5-cc54-f78fa19030b2e76a.ta \
    a3ba6512-6e0e-4065-93165e4a7d04ca08.ta \
    a734ee00-d6a1-4244-aa507c99719e7b7f.ta \
    d32d9207-6285-6d86-6cb98eaf46f6b4ec.ta; do
    grep -F "$ta" "$BEFOREMODULES" >/dev/null
done
grep -aF 'Keeping /odm mounted for recovery services' \
    "$RECOVERY_ROOT/system/bin/recovery" >/dev/null
grep -Fx 'mount_partition vendor /vendor' "$BEFOREMODULES" >/dev/null
grep -Fx 'mount_partition vendor_dlkm /vendor_dlkm' "$BEFOREMODULES" >/dev/null
grep -F 'mount_persist()' "$BEFOREMODULES" >/dev/null
grep -F 'mount -t ext4 -o rw,noatime,nosuid,nodev "$block" /persist' \
    "$BEFOREMODULES" >/dev/null
grep -F 'mount -o bind /persist /mnt/vendor/persist' "$BEFOREMODULES" >/dev/null
grep -Fx 'module_dir=/lib/modules' "$BEFOREMODULES" >/dev/null
grep -Fx 'load_module p73' "$BEFOREMODULES" >/dev/null
grep -Fx 'module_dir=/vendor_dlkm/lib/modules' "$BEFOREMODULES" >/dev/null
grep -Fx 'load_module leds-mt6379pmic' "$BEFOREMODULES" >/dev/null
grep -Fx 'load_module cs40l26-i2c' "$BEFOREMODULES" >/dev/null
grep -F 'allow tee nfc_device:chr_file { ioctl read write open };' \
    "$CRYPTO_DEVICE_POLICY" >/dev/null
grep -F 'allow hal_secure_element_default mitee_client_device:chr_file { ioctl read write getattr lock append map open watch watch_reads };' \
    "$CRYPTO_DEVICE_POLICY" >/dev/null
grep -F 'mkdir /config/usb_gadget/g1/functions/ffs.mtp' \
    "$RECOVERY_ROOT/init.recovery.usb.rc" >/dev/null
grep -F 'mount functionfs mtp /dev/usb-ffs/mtp' \
    "$RECOVERY_ROOT/init.recovery.usb.rc" >/dev/null
grep -F 'sys.usb.ffs.mtp.ready=1' \
    "$RECOVERY_ROOT/init.recovery.usb.rc" >/dev/null
grep -F 'write /config/usb_gadget/g1/idProduct 0x4EE2' \
    "$RECOVERY_ROOT/init.recovery.usb.rc" >/dev/null
grep -F '/devices/platform/soc/16701000.usb0/16700000.xhci0/usb* /usb_otg auto defaults voldmanaged=usb:auto' \
    "$RECOVERY_ROOT/system/etc/recovery.fstab" >/dev/null

"$MKBOOTFS" "$PLATFORM_ROOT" >"$SCRATCH/platform.cpio"
"$LZ4" -l -12 -f "$SCRATCH/platform.cpio" "$DEPLOY_OUT/vendor_ramdisk_platform.lz4"
"$MKBOOTFS" "$RECOVERY_ROOT" >"$SCRATCH/recovery.cpio"
"$LZ4" -l -12 -f "$SCRATCH/recovery.cpio" "$DEPLOY_OUT/vendor_ramdisk_recovery.lz4"

"$MKBOOTIMG" \
    --dtb "$DTB" \
    --base 0x00000000 \
    --pagesize 4096 \
    --vendor_cmdline 'bootopt=64S3,32N2,64N2 erofs.reserved_pages=64' \
    --header_version 4 \
    --kernel_offset 0x80000000 \
    --ramdisk_offset 0xa6f00000 \
    --tags_offset 0x87c80000 \
    --dtb_offset 0x0000000087c80000 \
    --vendor_ramdisk "$DEPLOY_OUT/vendor_ramdisk_platform.lz4" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$DEPLOY_OUT/vendor_ramdisk_recovery.lz4" \
    --vendor_boot "$DEPLOY_OUT/vendor_boot-dali-raw.img"

raw_size="$(stat -c %s "$DEPLOY_OUT/vendor_boot-dali-raw.img")"
test "$raw_size" -le "$MAX_FOOTER_INPUT_SIZE"

cp "$DEPLOY_OUT/vendor_boot-dali-raw.img" "$DEPLOY_OUT/OrangeFox-dali-vendor_boot-dev.img"
python3 "$AVBTOOL" add_hash_footer \
    --image "$DEPLOY_OUT/OrangeFox-dali-vendor_boot-dev.img" \
    --partition_name vendor_boot \
    --partition_size "$PARTITION_SIZE" \
    --salt "$AVB_SALT" \
    --algorithm NONE
test "$(stat -c %s "$DEPLOY_OUT/OrangeFox-dali-vendor_boot-dev.img")" -eq "$PARTITION_SIZE"

mkdir -p "$SCRATCH/unpacked"
python3 "$UNPACK_BOOTIMG" \
    --boot_img "$DEPLOY_OUT/OrangeFox-dali-vendor_boot-dev.img" \
    --out "$SCRATCH/unpacked" \
    --format=info >"$DEPLOY_OUT/vendor_boot-info.txt"
cmp "$SCRATCH/unpacked/vendor-ramdisk-by-name/ramdisk_" \
    "$DEPLOY_OUT/vendor_ramdisk_platform.lz4"
cmp "$SCRATCH/unpacked/vendor-ramdisk-by-name/ramdisk_recovery" \
    "$DEPLOY_OUT/vendor_ramdisk_recovery.lz4"
cmp "$SCRATCH/unpacked/dtb" "$DTB"

"$LZ4" -t "$DEPLOY_OUT/vendor_ramdisk_platform.lz4"
"$LZ4" -t "$DEPLOY_OUT/vendor_ramdisk_recovery.lz4"
python3 "$AVBTOOL" info_image \
    --image "$DEPLOY_OUT/OrangeFox-dali-vendor_boot-dev.img" \
    >"$DEPLOY_OUT/avb-info.txt"
grep -F "Salt:                  $AVB_SALT" "$DEPLOY_OUT/avb-info.txt" >/dev/null
final_digest="$(awk '$1 == "Digest:" {print $2; exit}' "$DEPLOY_OUT/avb-info.txt")"
test "${#final_digest}" -eq 64
test "$final_digest" != "$STOCK_TOP_VBMETA_DIGEST"

cat >"$DEPLOY_OUT/DEPLOYMENT.txt" <<EOF
Device: dali / 25060RK16C / mt6991
Table: PLATFORM (anonymous) -> RECOVERY (recovery)
Compression: LZ4 legacy for both entries
Raw image bytes: $raw_size
Partition image bytes: $PARTITION_SIZE
Stock top-level vbmeta vendor_boot digest: 75254351fb4c27ccb69d60eab1c9aabf09de9abb791c7665137eca99241c87be
Development image self descriptor digest: $final_digest

OrangeFox-dali-vendor_boot-dev.img is an unsigned development image. The
connected device is currently locked/green and its signed top-level vbmeta
expects the stock digest above. Runtime testing starts after the bootloader is
in a state that permits a changed vendor_boot digest.
EOF

(
    cd "$DEPLOY_OUT"
    sha256sum \
        OrangeFox-dali-vendor_boot-dev.img \
        vendor_boot-dali-raw.img \
        vendor_ramdisk_platform.lz4 \
        vendor_ramdisk_recovery.lz4 \
        vendor_boot-info.txt \
        avb-info.txt \
        DEPLOYMENT.txt >SHA256SUMS
)

printf 'DALI_VENDOR_BOOT_STRUCTURE_OK %s\n' "$DEPLOY_OUT"
cat "$DEPLOY_OUT/SHA256SUMS"
