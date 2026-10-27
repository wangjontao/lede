#!/bin/bash
set -euo pipefail
./scripts/feeds update -a
./scripts/feeds install -a
# Force only the requested versions over the ordinary LuCI feed copies.
./scripts/feeds install -f -p passwall2 luci-app-passwall2
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile
grep -q 'PKG_RELEASE:=1' feeds/passwall2/luci-app-passwall2/Makefile
cp custom/rax3000m-nand/config.seed .config
make defconfig
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m-nand=y$' .config
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall2 luci-app-homeproxy luci-app-filetransfer luci-app-package-manager luci-theme-argon luci-app-ttyd luci-app-nps npc; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }
done
# Streaming QoS: fail the build instead of silently producing an image without cake.
for p in tc-tiny kmod-sched-core kmod-sched-cake kmod-ifb sqm-scripts luci-app-sqm; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "SQM package missing: $p"; exit 1; }
done
# Shared overlay assembly (root password, dashboard, NPS hooks, hotplug, QoS guard).
bash scripts/juilang-overlay.sh

# Proxy node configuration is NOT baked in: custom/device/passwall2 carried real
# node addresses and UUIDs and this repository is public. Restore it from the
# device backup (/root/config-backups) or re-enter the nodes in LuCI.
./scripts/diffconfig.sh > build.config
for feed in feeds/*/.git; do [ -d "$feed" ] && printf '%s %s\n' "$feed" "$(git -C "${feed%/.git}" rev-parse HEAD)"; done > feeds.lock.actual
