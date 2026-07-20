#!/system/bin/sh

status=/tmp/dali-beforemodules.status
module_log=/tmp/dali-beforemodules.modprobe.log
module_dir=/lib/modules

: > "$status"
: > "$module_log"

record_status() {
    echo "$1" >> "$status"
}

slot="$(getprop ro.boot.slot_suffix)"
if [ -z "$slot" ]; then
    slot_name="$(getprop ro.boot.slot)"
    [ -n "$slot_name" ] && slot="_${slot_name}"
fi
record_status "slot:${slot}"

mount_partition() {
    partition="$1"
    target="$2"

    if grep -q " ${target} " /proc/mounts; then
        record_status "mount:${partition}:already-mounted"
        return 0
    fi

    mkdir -p "$target"
    for block in "/dev/block/mapper/${partition}${slot}" \
        "/dev/block/by-name/${partition}"; do
        [ -e "$block" ] || continue
        if mount -t erofs -o ro "$block" "$target"; then
            record_status "mount:${partition}:erofs:${block}"
            return 0
        fi
        if mount -t ext4 -o ro "$block" "$target"; then
            record_status "mount:${partition}:ext4:${block}"
            return 0
        fi
    done

    record_status "mount:${partition}:failed"
    return 1
}

if mount_partition odm /odm && \
    [ -r /odm/mitee/ta/123af5d1-d6f5-cc54-f78fa19030b2e76a.ta ] && \
    [ -r /odm/mitee/ta/a3ba6512-6e0e-4065-93165e4a7d04ca08.ta ] && \
    [ -r /odm/mitee/ta/a734ee00-d6a1-4244-aa507c99719e7b7f.ta ] && \
    [ -r /odm/mitee/ta/d32d9207-6285-6d86-6cb98eaf46f6b4ec.ta ]; then
    record_status 'odm:mitee-ta:ready'
else
    record_status 'odm:mitee-ta:unavailable'
fi
mount_partition vendor /vendor
mount_partition vendor_dlkm /vendor_dlkm

# Stock MITEe services use the real persist filesystem at
# /mnt/vendor/persist. Recovery does not auto-mount that fstab entry, so mount
# the measured Dali persist block first, then bind it to the stock service path
# before KeyMint is started from init.recovery.mt6991.rc.
mount_persist() {
    if grep -q ' /persist ' /proc/mounts; then
        record_status 'mount:persist:already-mounted'
        return 0
    fi

    mkdir -p /persist
    for block in /dev/block/by-name/persist /dev/block/sdc9; do
        [ -e "$block" ] || continue
        if mount -t ext4 -o rw,noatime,nosuid,nodev "$block" /persist; then
            record_status "mount:persist:ext4:${block}"
            return 0
        fi
    done

    record_status 'mount:persist:failed'
    return 1
}

if mount_persist; then
    mkdir -p /mnt/vendor/persist
    if grep -q ' /mnt/vendor/persist ' /proc/mounts; then
        record_status 'mount:persist-bind:already-mounted'
    elif mount -o bind /persist /mnt/vendor/persist; then
        record_status 'mount:persist-bind:mounted'
    else
        record_status 'mount:persist-bind:failed'
    fi
else
    record_status 'mount:persist-bind:source-unavailable'
fi

if [ -s /vendor/firmware/cs40l26.wmfw ] && \
    [ -s /vendor/firmware/cs40l26.bin ]; then
    record_status firmware:cs40l26:present
else
    record_status firmware:cs40l26:absent
fi

load_module() {
    module="$1"
    module_name="$(echo "$module" | tr '-' '_')"

    if grep -q "^${module_name} " /proc/modules; then
        record_status "module:${module}:already-loaded"
        return 0
    fi
    if [ ! -s "$module_dir/modules.dep" ]; then
        record_status "module:${module}:modules.dep-absent"
        return 1
    fi
    if modprobe -d "$module_dir" "$module" >> "$module_log" 2>&1; then
        if grep -q "^${module_name} " /proc/modules; then
            record_status "module:${module}:loaded"
            return 0
        fi
        record_status "module:${module}:not-listed-after-modprobe"
        return 1
    fi

    record_status "module:${module}:modprobe-failed"
    return 1
}

# The connected Dali's stock PLATFORM ramdisk contains the NXP eSE transport
# and its dependency graph. It must be loaded before twrp.modules.loaded so the
# following init action can apply the stock nfc:nfc ownership to /dev/p73.
load_module p73

# These are the only stock vendor_dlkm targets selected by the connected Dali's DT.
module_dir=/vendor_dlkm/lib/modules
load_module leds-mt6379pmic
load_module cs40l26-i2c

record_status done
exit 0
