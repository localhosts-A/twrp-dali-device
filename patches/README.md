# Companion Patches

These patches are generated from the exact OrangeFox16 baseline recorded in
`apply_dali_patches.sh`. They are separate from the device tree because they
change shared Recovery framework behavior required by Dali hardware.

| Patch | Project | Required behavior |
| --- | --- | --- |
| `0001-build-make.patch` | `build/make` | vendor_boot Recovery build and device hook plumbing |
| `0002-bootable-recovery.patch` | `bootable/recovery` | mounted vendor/ODM retention, module loading, touch raw-mode handling, haptics, Dali theme resources, and recovery service integration |
| `0003-external-se-omapi.patch` | `external/se_omapi` | native eSE/OMAPI bridge with sensitive transport logging removed |
| `0004-system-vold.patch` | `system/vold` | Dali Weaver protector parsing and Keystore2 FBE handling |
| `0005-system-sepolicy.patch` | `system/sepolicy` | Recovery secure-element policy and service access |

The device-specific init services, module ordering, SELinux labels, VINTF
snapshots and ramdisk repack logic remain inside `device/xiaomi/dali`.
