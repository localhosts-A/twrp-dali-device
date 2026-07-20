#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="${1:?usage: apply_dali_patches.sh SOURCE_ROOT}"
BUNDLE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

test -d "$SOURCE_ROOT/.repo" || {
    echo "not an Android repo root: $SOURCE_ROOT" >&2
    exit 2
}

check_head() {
    local project="$1"
    local expected="$2"
    local actual
    actual="$(git -C "$SOURCE_ROOT/$project" rev-parse HEAD)"
    case "$actual" in
        "$expected"*) ;;
        *)
        echo "baseline mismatch in $project: expected $expected, got $actual" >&2
        exit 3
        ;;
    esac
}

apply_project_patch() {
    local project="$1"
    local patch_name="$2"
    git -C "$SOURCE_ROOT/$project" apply --check "$BUNDLE_ROOT/patches/$patch_name"
    git -C "$SOURCE_ROOT/$project" apply "$BUNDLE_ROOT/patches/$patch_name"
}

check_head build/make f490f02
check_head bootable/recovery bb7a6528
check_head system/vold 953de96
check_head system/sepolicy bb10083

if [ -e "$SOURCE_ROOT/external/se_omapi" ]; then
    check_head external/se_omapi 637d191
else
    mkdir -p "$SOURCE_ROOT/external"
    cp -a "$BUNDLE_ROOT/dependencies/external/se_omapi" "$SOURCE_ROOT/external/"
fi

apply_project_patch build/make 0001-build-make.patch
apply_project_patch bootable/recovery 0002-bootable-recovery.patch
apply_project_patch external/se_omapi 0003-external-se-omapi.patch
apply_project_patch system/vold 0004-system-vold.patch
apply_project_patch system/sepolicy 0005-system-sepolicy.patch

echo "Dali device tree patches applied"
