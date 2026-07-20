# OrangeFox16 Dali Device Tree

This is the evidence-derived OrangeFox16 device-tree bundle for the connected
Redmi 25060RK16C (`dali`, MT6991). The tree was built from the connected
device's partitions, hardware nodes, service logs, VINTF information, and
Recovery test results. It does not import a finished tree from another device.

Bundle location on the build server:

```text
/root/orangefox16-dali-device-tree
```

The bundle targets the OrangeFox16 source baseline recorded by
`patches/apply_dali_patches.sh`. It is separate from the OrangeFox14.1 source
tree.

## What Is Included

| Path | Purpose |
| --- | --- |
| `device/xiaomi/dali/` | Device configuration, stock DTB/kernel/PLATFORM ramdisk, fstab, init actions, VINTF data, SELinux labels, AP touch modules, and build tools. |
| `dependencies/external/se_omapi/` | Native OMAPI bridge used by the Dali eSE, NXP Weaver, and FBE path. |
| `patches/` | Exact OrangeFox16 framework patches plus their application helper. |
| `checksums.sha256` | SHA-256 manifest for all exported regular files. |

The active configuration has these measured properties:

- The active-slot ODM partition is mounted before the touch/eSE module flow.
- Goodix touch uses the original ODM firmware. There is no built-in Goodix
  firmware fallback in the Recovery ramdisk.
- FBE uses MITEe KeyMint/Gatekeeper, NXP Weaver, Keystore2, OMAPI, and the
  eSE service under enforcing SELinux.
- Flashlight, CS40L26 haptics, MTP FunctionFS, and OTG fstab configuration are
  present.
- Default language is Simplified Chinese. The default time zone is the
  portrait_hdpi UTC+8 selector `TAIST-8;TAIDT`, with DST disabled.
- There is no `ro.sf.lcd_density=` override. Framebuffer and portrait_hdpi
  canvas values remain as display geometry, not DPI tuning.

## Verify The Export

Run this before importing the bundle:

```sh
cd /root/orangefox16-dali-device-tree
sha256sum -c checksums.sha256
```

Every line should end with `OK`.

## Import Into OrangeFox16

Start with the exact OrangeFox16 baseline expected by the helper. The helper
checks these project heads before it changes the source tree:

```text
build/make          f490f02
bootable/recovery   bb7a6528
external/se_omapi   637d191
system/vold         953de96
system/sepolicy     bb10083
```

Set the two paths and import the tree:

```sh
BUNDLE=/root/orangefox16-dali-device-tree
SOURCE_ROOT=/work/orangefox16/fox_16.0

mkdir -p "$SOURCE_ROOT/device/xiaomi"
cp -a "$BUNDLE/device/xiaomi/dali" "$SOURCE_ROOT/device/xiaomi/"
"$BUNDLE/patches/apply_dali_patches.sh" "$SOURCE_ROOT"
```

`apply_dali_patches.sh` installs `external/se_omapi` from the bundle when it
is absent and applies the five framework patches once. Those patches stay
outside the device directory because they change shared Recovery, vold,
SELinux, and build-framework behavior. The helper stops on a baseline mismatch
and prints the expected and actual revision, which prevents applying an exact
patch set to an unrelated source revision.

## Build

```sh
cd "$SOURCE_ROOT"
source build/envsetup.sh
lunch twrp_dali-bp2a-eng
export FOX_BUILD_TYPE=Beta
mka -j"$(nproc)" adbd vendorbootimage
device/xiaomi/dali/tools/build_dali_vendor_boot.sh
device/xiaomi/dali/tools/verify_dali_vendor_boot.sh
```

The deployable image is:

```text
out/target/product/dali/dali-deploy/OrangeFox-dali-vendor_boot-dev.img
```

`verify_dali_vendor_boot.sh` must end with:

```text
VERIFY_DALI_VENDOR_BOOT_STRUCTURE_OK
```

It validates the vendor_boot v4/AVB structure, byte-preserved stock PLATFORM
payload, Recovery ramdisk contents, FBE/eSE service files, MTP/OTG setup,
ODM-only touch firmware, and portrait_hdpi resources.

## Flash With Fastboot

Use the slot reported by the connected device. The measured device was on slot
`b` during this work; always read the current result before selecting a target
partition.

```sh
fastboot devices
fastboot getvar current-slot

# Example when fastboot reports: current-slot: b
fastboot flash vendor_boot_b \
  out/target/product/dali/dali-deploy/OrangeFox-dali-vendor_boot-dev.img
fastboot reboot recovery
```

## First-Boot Checks

After Recovery starts, verify the hardware functions from the OrangeFox UI:

1. Touch input and display orientation.
2. Data decryption using the current screen-lock credential.
3. Flashlight and vibration tests.
4. MTP after data is ready, then an OTG storage device.
5. Simplified Chinese and UTC+8 selection in settings.

For host-side diagnostics:

```sh
adb wait-for-device
adb shell getenforce
adb shell twrp get tw_is_decrypted
adb shell twrp get tw_time_zone
adb shell twrp get tw_time_zone_guisel
adb shell twrp get tw_time_zone_guidst
```

The expected time-zone values from a freshly built image are `TAIST-8`,
`TAIST-8;TAIDT`, and `0` respectively. MTP and OTG device nodes are defined in
the tree; enable MTP through the OrangeFox UI once the required storage is
ready.

## Maintaining The Bundle

Keep `prebuilt/vendor_ramdisk_platform.lz4` byte-preserved because it is the
stock PLATFORM payload required by the target's vendor_boot layout. Keep the
device directory, OMAPI dependency, and framework patches together. When the
OrangeFox16 baseline advances, regenerate and validate the patches against the
new revisions before replacing the recorded baseline values.
