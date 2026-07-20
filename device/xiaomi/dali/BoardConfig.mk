# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/dali

ALLOW_MISSING_DEPENDENCIES := true
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true
BUILD_BROKEN_PLUGIN_VALIDATION := soong-libaosprecovery_defaults soong-libguitwrp_defaults soong-libminuitwrp_defaults soong-vold_defaults

# Architecture: the stock userspace exposes only arm64-v8a.
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic

# Platform identity from getprop and bootconfig.
TARGET_BOARD_PLATFORM := mt6991
TARGET_BOOTLOADER_BOARD_NAME := mt6991
TARGET_NO_BOOTLOADER := true
BOARD_SHIPPING_API_LEVEL := 35

# Stock boot header v4 parameters from unpack_bootimg.py.
TARGET_KERNEL_ARCH := arm64
TARGET_KERNEL_HEADER_ARCH := arm64
BOARD_KERNEL_IMAGE_NAME := Image.lz4
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel.lz4
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 erofs.reserved_pages=64
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset 0x80000000
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0xa6f00000
BOARD_MKBOOTIMG_ARGS += --tags_offset 0x87c80000
BOARD_MKBOOTIMG_ARGS += --dtb_offset 0x0000000087c80000

# The exact DTB blob extracted from stock vendor_boot.
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb

# Physical partition sizes measured with blockdev --getsize64.
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608

# Stock vendor_boot has a PLATFORM fragment followed by a RECOVERY fragment.
# The AOSP target below is only the compile staging image. tools/build_dali_vendor_boot.sh
# rebuilds the deployable two-entry image from the measured stock platform files.
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true

# This development image is intentionally emitted without an unknown OEM AVB key.
BOARD_AVB_ENABLE := false

# A/B and dynamic partition metadata from lpdump slot _b. Stock super contains
# mi_ext, but it has no Recovery consumer and is intentionally omitted from
# recovery.fstab; this recovery-only product has no mi_ext image type.
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS := \
    boot \
    init_boot \
    vendor_boot \
    dtbo \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    system \
    system_ext \
    system_dlkm \
    product \
    vendor \
    vendor_dlkm \
    odm \
    odm_dlkm

BOARD_SUPER_PARTITION_SIZE := 11811160064
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 11800674304
BOARD_MAIN_PARTITION_LIST := \
    system \
    system_ext \
    system_dlkm \
    product \
    vendor \
    vendor_dlkm \
    odm \
    odm_dlkm

TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Stock /data is F2FS with metadata-backed file encryption. System-side logs
# from this device show vold reading /metadata/vold/metadata_encryption/key
# through MITEe KeyMint before mounting /data.
BOARD_USES_METADATA_PARTITION := true
# TW_INCLUDE_CRYPTO also enables OrangeFox's FBE metadata-decrypt path.
TW_INCLUDE_CRYPTO := true
# Dali's NXP Weaver talks to the eSE through the OMAPI AIDL service. Recovery
# has no Java framework, so package OrangeFox's native OMAPI bridge.
TW_INCLUDE_OMAPI := true
# The Dali MITEe, Gatekeeper, and Weaver binaries stay on /vendor while a PIN
# is entered, so retain the real vendor filesystem for the Recovery session.
TW_USES_VENDOR_LIBS := true
# Dali's MITEe trusted applications are loaded from the measured active ODM
# filesystem after module setup, so do not let PartitionManager unmount it.
TW_KEEP_ODM_MOUNTED := true
# Keystore2 is packaged in the Recovery ramdisk. The observed service path
# reaches the metadata mount before apexd status becomes available.
TW_EXCLUDE_APEX := true

# ueventd coldboots MITEe/RPMB nodes before Recovery can mount /vendor. Build
# their Dali-specific labels and policy into the recovery ramdisk itself.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Recovery layout and maintenance tools. Optional Fox Addons are disabled in
# vendorsetup.sh and the deploy script removes any stale FFiles directory.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
TW_SKIP_ADDITIONAL_FSTAB := true
TW_INCLUDE_FASTBOOTD := true
TW_INCLUDE_LPDUMP := true
TW_INCLUDE_LPTOOLS := true
TW_INCLUDE_REPACKTOOLS := true
TW_EXCLUDE_BASH := true
TW_EXCLUDE_NANO := true
TW_EXCLUDE_ZIP := true
# OrangeFox's FFS MTP implementation is paired with the Dali configfs
# triggers in recovery/root/init.recovery.usb.rc.
TW_EXCLUDE_DEFAULT_USB_INIT := true
TARGET_USES_MKE2FS := true
RECOVERY_SDCARD_ON_DATA := true

# Recovery boot mode omits the SCP carveouts used by the normal Android boot.
# The RECOVERY ramdisk supplies this device's verified AP-only SCP/Goodix
# modules plus the stock Xiaomi touch framework, so load Goodix from the merged
# vendor_boot module directory before considering vendor_dlkm.
TW_LOAD_VENDOR_BOOT_MODULES := true
TW_LOAD_VENDOR_MODULES := "goodix_core_dali.ko"
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true

# The device's working recovery log uses XBGR8888 at 1280x2772. OrangeFox's
# minuitwrp maps RGBX_8888 to that DRM format and a 32-bit RGBA draw surface.
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TW_THEME := portrait_hdpi
# Status layout values live in fox_dali.mk because portrait_hdpi scales them.
# Measured on the connected Dali panel: DRM DSI mode is 1280x2772.
DEVICE_RESOLUTION := 1280x2772
TARGET_SCREEN_WIDTH := 1280
TARGET_SCREEN_HEIGHT := 2772
# Include the bundled Simplified/Traditional Chinese language packs and fonts.
TW_EXTRA_LANGUAGES := true
TW_DEFAULT_LANGUAGE := zh_CN
# Match the portrait_hdpi UTC+8 selector; TW_TIME_ZONE_GUIDST remains 0.
OF_DEFAULT_TIMEZONE := TAIST-8;TAIDT
TW_FRAMERATE := 60
TW_BRIGHTNESS_PATH := "/sys/class/leds/lcd-backlight/brightness"
TW_MAX_BRIGHTNESS := 16383
TW_DEFAULT_BRIGHTNESS := 1228
# The standard 60-second timer still writes the OLED backlight to 0. Keep the
# framebuffer awake path until a full DRM blank/wake cycle is validated on Dali.
TW_NO_SCREEN_BLANK := true
