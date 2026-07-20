# OrangeFox 16 device tree for dali

This tree was generated from the connected `dali` device. No hardware value
was copied from another device tree.

## Evidence-backed layout

- Product: Redmi `25060RK16C`, platform `mt6991`.
- Android 16 / API 36 system with an Android 15 / API 35 vendor base.
- Linux 6.6.118 GKI, 4 KiB pages, arm64-only userspace.
- Virtual A/B and dynamic partitions; no standalone recovery partition.
- The stock `mi_ext` logical partition has no Recovery consumer. Its two fstab
  alternatives each produced an unsuccessful logical-partition update during
  cold boot, so it is intentionally omitted from `recovery.fstab`; stock super
  metadata remains untouched.
- Stock `vendor_boot` header v4 contains a PLATFORM ramdisk fragment and a
  RECOVERY ramdisk fragment. The PLATFORM fragment, DTB, addresses, page size,
  and vendor cmdline in this tree are byte-exact stock exports.
- Recovery display parameters are configured from the active
  `o12_42_02_0a_dsc_cmd,lcm`, DRM DSI-1, 1280x2772, rotation 0. The device's
  working recovery log selects DRM XBGR8888, so minuitwrp is built as RGBX_8888.
  The portrait_hdpi XML canvas is 1080x1920: `OF_SCREEN_H=1920`,
  `OF_STATUS_H=105` and 81-pixel status indents are logical coordinates that
  scale to the measured framebuffer. Backlight node is
  `/sys/class/leds/lcd-backlight/brightness`, maximum 16383.
- The active touch device is `goodix_ts` on SPI6. A current-device
  `last_kmsg` proved that the stock Goodix dependency chain enters `scp.ko`,
  while the Recovery FDT omits the normal Android SCP carveouts; the resulting
  `scp_region_info_init()` Oops caused the original reboot loop. The RECOVERY
  ramdisk therefore overlays three modules extracted from this device: the
  stock Xiaomi touch framework, an SCP export shim whose hardware init returns
  before touching absent carveouts, and Goodix with only its optional
  `scp_tp_init()` path disabled. The AP path was then loaded on the connected
  device: Goodix matched its firmware/config, created `goodix_ts`/`event2`, and
  reported complete `ABS_MT`, `BTN_TOUCH` and `SYN_REPORT` events.
- Goodix later-init defaults to THP/raw mode even though Xiaomi's
  `enable_touch_raw` cache reads `0`. The connected device produced no evdev
  coordinates until writing `0` through that sysfs interface; this invokes the
  registered Goodix raw-disable/coordinate-enable callback. Recovery performs
  the same write after `twrp.modules.loaded=true`, with a 250 ms allowance
  for Goodix later-init. Before module loading, the device-specific
  `beforemodules.sh` hook mounts the active slot's already-mapped logical ODM,
  vendor and vendor_dlkm partitions read-only, trying EROFS and then ext4. This
  makes the kernel's measured `/vendor/firmware,/odm/firmware` search path and
  stock vendor_dlkm dependency index available before Goodix probes. The two
  named Goodix firmware blobs are also exact `/odm/firmware` exports from this
  device. Recovery carries no Goodix firmware fallback; the mounted ODM copy is
  the only touch firmware source.
- The connected device's flashlight DT node is
  `mediatek,mt6379-pmicflash`. Loading only its stock vendor_dlkm target,
  `leds-mt6379pmic`, through `modprobe` also resolves the measured flashlight
  dependency chain. It creates three LED class devices, but only
  `/sys/class/leds/white:flash-1` is selected for OrangeFox: writing brightness
  30 of its measured maximum 75 for five seconds produced a clearly visible
  torch. The separately tested flash-2 and flash-3 paths are not adopted.
- The haptic device is the connected device's `cirrus,cs40l26a` at I2C
  `1-0043`. `beforemodules.sh` requests only `cs40l26-i2c`; stock modules.dep
  resolves `cs40l26-core` and `cl_dsp-core`, while the mounted vendor supplies
  the exact `cs40l26.wmfw` and `cs40l26.bin` firmware. The resulting
  `cs40l26_input` exposes EV_FF. Five 500 ms force-feedback pulses at magnitude
  24576 produced a repeatable physical response on the connected device.
- Recovery USB controller: `16701000.usb0`. OrangeFox is built with its FFS
  MTP implementation enabled. The device-owned `init.recovery.usb.rc`
  declares the measured configfs MTP function, its Windows OS descriptors and
  the `mtp,adb` binding; the stock ADB FunctionFS remains available for the
  normal Recovery toggle. The USB host path is declared separately in
  `recovery.fstab` with the measured xHCI uevent path and
  `voldmanaged=usb:auto`.
- Metadata and credential-encrypted `/data` were verified on the connected
  device. Recovery starts the stock eSE, OMAPI, Weaver, KeyMint and Keystore2
  chain, parses the device's `.weaver` protector format, and reaches
  `twrp.user.0.decrypt=1`. No startup APEX mount is required for this path.

## Build

```sh
source build/envsetup.sh
lunch twrp_dali bp2a eng
export FOX_BUILD_TYPE=Beta
mka clean-relink_libraries
mka adbd vendorbootimage
device/xiaomi/dali/tools/build_dali_vendor_boot.sh
device/xiaomi/dali/tools/verify_dali_vendor_boot.sh
```

The AOSP `vendorbootimage` target is a compile staging artifact. The device
ships a large PLATFORM fragment that also contains the stock recovery UI; a
complete OrangeFox RECOVERY fragment beside that duplicate UI exceeds the
measured 64 MiB partition.

`tools/build_dali_vendor_boot.sh` creates the deployable image directly from
the connected device's stock PLATFORM archive and the compiled OrangeFox root.
It keeps every stock kernel module, first-stage fstab, SELinux/property context
and device rc file. It drops the replaced stock `res/` and only those
`system/` paths that OrangeFox also supplies, preserving 28 stock-only MTK
boot, health and fastboot HAL files and dependencies. It emits two LZ4 legacy
table entries in the stock order: anonymous PLATFORM followed by `recovery`.
The RECOVERY entry overlays only the three verified touch modules and their
stock-derived dependency map; flashlight and haptic modules are loaded in place from the active
slot's stock vendor_dlkm after its dependency index and vendor firmware are
mounted. The stock PLATFORM entry remains byte-for-byte preserved.
The scripts verify source hashes, the complete v4 header/table contract, DTB,
LZ4 streams, retained MTK files and the measured partition limit.

The stock device reports a locked, green AVB state. This tree produces an
unsigned development image because the OEM signing key is not present in the
device or source checkout.
