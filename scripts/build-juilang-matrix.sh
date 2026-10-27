#!/bin/bash
# Build every device of one group in a single multi-profile run.
#
#   scripts/build-juilang-matrix.sh <group> [devices.txt]
#
# Each group produces one image per device, named
#   release/JuLiangOS-<TAG>-sysupgrade.bin
# plus manifests, the effective config and SHA256SUMS.
set -euo pipefail
cd "$(dirname "$0")/.."

GROUP="${1:?usage: $0 <group> [devices.txt]}"
DEVFILE="${2:-custom/matrix/devices.txt}"
TARGET="mediatek_filogic"

mapfile -t ROWS < <(awk -v g="$GROUP" '$1 == g && $2 !~ /^#/ { print $2 " " $3 }' "$DEVFILE")
if [ "${#ROWS[@]}" -eq 0 ]; then
    echo "No devices listed for group ${GROUP} in ${DEVFILE}" >&2
    exit 1
fi
echo "Group ${GROUP}: ${#ROWS[@]} device(s)"
printf '  %s\n' "${ROWS[@]}"

# --- feeds and packages ---------------------------------------------------
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -f -p passwall2 luci-app-passwall2
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile

# --- configuration --------------------------------------------------------
cp custom/matrix/config.seed .config
{
    echo 'CONFIG_TARGET_MULTI_PROFILE=y'
    echo 'CONFIG_TARGET_PER_DEVICE_ROOTFS=y'
    for row in "${ROWS[@]}"; do
        set -- $row
        echo "CONFIG_TARGET_DEVICE_${TARGET}_DEVICE_$1=y"
    done
} >> .config

make defconfig

# Fail loudly instead of silently producing a single-device image.
grep -qx 'CONFIG_TARGET_MULTI_PROFILE=y' .config || {
    echo "CONFIG_TARGET_MULTI_PROFILE was dropped by defconfig" >&2
    exit 1
}
grep -qx 'CONFIG_TARGET_PER_DEVICE_ROOTFS=y' .config || {
    echo "CONFIG_TARGET_PER_DEVICE_ROOTFS was dropped by defconfig" >&2
    exit 1
}
for row in "${ROWS[@]}"; do
    set -- $row
    grep -q "^CONFIG_TARGET_DEVICE_${TARGET}_DEVICE_$1=y$" .config || {
        echo "Device not retained in .config: $1" >&2
        exit 1
    }
done
for p in luci-app-passwall2 luci-app-homeproxy luci-app-nps npc luci-app-sqm sqm-scripts \
         kmod-sched-cake kmod-ifb tc-tiny luci-theme-argon luci-app-ttyd; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || {
        echo "Required package missing: $p" >&2
        exit 1
    }
done

# --- overlay --------------------------------------------------------------
bash scripts/juilang-overlay.sh

# --- build ----------------------------------------------------------------
make download -j"$(nproc)" || true
make -j"$(nproc)" || make -j1 V=s

# --- collect --------------------------------------------------------------
mkdir -p release
for row in "${ROWS[@]}"; do
    set -- $row
    dev="$1"; tag="$2"
    img="$(find bin/targets/mediatek/filogic -name "*${dev}*sysupgrade.bin" -size +5M | head -n1)"
    man="$(find bin/targets/mediatek/filogic -name "*${dev}*.manifest" | head -n1)"
    if [ -z "$img" ]; then
        echo "No sysupgrade image produced for ${dev}" >&2
        exit 1
    fi
    cp "$img" "release/JuLiangOS-${tag}-sysupgrade.bin"
    if [ -n "$man" ]; then
        cp "$man" "release/JuLiangOS-${tag}.manifest"
        grep -q '^luci-app-sqm ' "release/JuLiangOS-${tag}.manifest" || {
            echo "SQM missing from ${tag} manifest" >&2
            exit 1
        }
    fi
    echo "collected ${tag} <- $(basename "$img")"
done

cp .config release/build.config
(cd release && sha256sum * > SHA256SUMS && ls -lh)
