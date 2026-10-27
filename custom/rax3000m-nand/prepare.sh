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
for p in tc kmod-sched-core kmod-sched-cake kmod-ifb sqm-scripts luci-app-sqm; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "SQM package missing: $p"; exit 1; }
done
HASH="$(openssl passwd -1 '@password@')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s\n' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot

# Overlay captured from the running system: JuLiang dashboard, NPS hooks, hotplug.
mkdir -p files
cp -a custom/rax3000m-nand/files/. files/
for f in etc/init.d/dulwifi-firstboot etc/init.d/juliang-dashboard etc/init.d/wan-lease-guard \
         etc/uci-defaults/96-juliang-dashboard etc/uci-defaults/97-wan-guard etc/uci-defaults/99-enable-nps-wan-mac etc/uci-defaults/99-zz-dulwifi \
         etc/hotplug.d/iface/50-arpbind etc/hotplug.d/iface/98-passwall2 etc/hotplug.d/iface/99-fastacl252 \
         etc/hotplug.d/iface/99-mtk-lro etc/hotplug.d/iface/99-nps-wan-mac \
         usr/libexec/dulwifi-firstboot usr/libexec/nps-wan-mac usr/libexec/wan-lease-guard \
         usr/bin/juliang-traffic-daemon usr/bin/juliang-traffic-sample; do
    [ -e "files/$f" ] && chmod 755 "files/$f"
done

# Proxy node configuration is NOT baked in: custom/device/passwall2 carried real
# node addresses and UUIDs and this repository is public. Restore it from the
# device backup (/root/config-backups) or re-enter the nodes in LuCI.
./scripts/diffconfig.sh > build.config
for feed in feeds/*/.git; do [ -d "$feed" ] && printf '%s %s\n' "$feed" "$(git -C "${feed%/.git}" rev-parse HEAD)"; done > feeds.lock.actual
