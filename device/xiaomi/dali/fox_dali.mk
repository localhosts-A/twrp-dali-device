# SPDX-License-Identifier: GPL-3.0-or-later

OF_MAINTAINER := local

# The framebuffer is 1280x2772, while portrait_hdpi uses a 1080x1920 logical
# coordinate space that is scaled at render time. Values below are theme units.
OF_SCREEN_H := 1920
OF_STATUS_H := 105
OF_HIDE_NOTCH := 1

# Keep time and battery 96 physical pixels inside either panel edge:
# 81 logical px * (1280 / 1080) = 96 physical px.
OF_STATUS_INDENT_LEFT := 81
OF_STATUS_INDENT_RIGHT := 81

# The connected device exposes its working torch on this MT6379 PMIC LED.
OF_FLASHLIGHT_ENABLE := 1
OF_FL_PATH1 := /sys/class/leds/white:flash-1

OF_ENABLE_ALL_PARTITION_TOOLS := 1
OF_FORCE_DATA_FORMAT_F2FS := 1
OF_WIPE_METADATA_AFTER_DATAFORMAT := 1
OF_DYNAMIC_FULL_SIZE := 11811160064
OF_FORCE_PREBUILT_KERNEL := 1

# Measured vendor_boot capacity requires dropping optional console/root addons.
# Core UI, ADB, fastbootd, filesystems and module loading stay enabled.
FOX_ENABLE_KERNELSU_SUPPORT := 0
FOX_ENABLE_KERNELSU_NEXT_SUPPORT := 0
FOX_ENABLE_SUKISU_SUPPORT := 0
FOX_BUILD_BASH := 0
FOX_USE_BASH_SHELL := 0
FOX_ASH_IS_BASH := 0
FOX_USE_NANO_EDITOR := 0
FOX_REMOVE_BASH := 1
FOX_EXCLUDE_NANO_EDITOR := 1
FOX_EXCLUDE_ZIP := 1
FOX_REMOVE_ZIP_BINARY := 1
FOX_USE_ZSTD_BINARY := 0
FOX_USE_LZ4_BINARY := 0
