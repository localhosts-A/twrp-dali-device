# SPDX-License-Identifier: Apache-2.0

LOCAL_PATH := device/xiaomi/dali

PRODUCT_SHIPPING_API_LEVEL := 35
PRODUCT_TARGET_VNDK_VERSION := 35

# Stock system evidence identifies this as the top-level ROM fingerprint.
PRODUCT_SYSTEM_PROPERTIES += ro.build.fingerprint=Redmi/dali/dali:16/BP2A.250605.031.A3/OS3.0.305.0.WONCNXM:user/release-keys

PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := true

PRODUCT_PACKAGES += \
    fastbootd \
    lpdump \
    lpflash \
    lpunpack \
    snapuserd

PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

$(call inherit-product, $(LOCAL_PATH)/fox_dali.mk)
