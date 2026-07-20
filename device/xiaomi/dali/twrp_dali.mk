# SPDX-License-Identifier: Apache-2.0

DEVICE_PATH := device/xiaomi/dali

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/compression.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, $(DEVICE_PATH)/device.mk)

PRODUCT_NAME := twrp_dali
PRODUCT_DEVICE := dali
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := 25060RK16C
PRODUCT_MANUFACTURER := Xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="missi-user 16 BP2A.250605.031.A3 16OS3.1.260710.200938533.MTPECN.S release-keys"

BUILD_FINGERPRINT := Redmi/dali/dali:16/BP2A.250605.031.A3/OS3.0.305.0.WONCNXM:user/release-keys
