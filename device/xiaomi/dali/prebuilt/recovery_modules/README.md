# Dali Recovery touch modules

All three inputs came from the connected `25060RK16C` device's
`/vendor_dlkm/lib/modules` on 2026-07-19. No module came from another device
tree.

`xiaomi_touch_dali.ko` is byte-exact stock. `scp.ko` keeps its exports but its
Recovery-only `init_module` returns success before accessing SCP reserved
memory, which is absent from the Recovery FDT. `goodix_core_dali.ko` changes
only the optional `scp_tp_init()` result so the driver's AP coordinate path
continues. Pointer-authentication prologues/epilogues remain balanced.

`../../tools/patch_recovery_ap_modules.py` reproduces both patches and rejects
any source module whose SHA-256 differs from the device-extracted originals.
The patched outputs were loaded together on the connected device before being
included here; Goodix probe, firmware/config matching and evdev coordinate
reporting were all observed over ADB.
