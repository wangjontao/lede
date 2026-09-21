#!/bin/bash
set -euo pipefail
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -f -p passwall luci-app-passwall
./scripts/feeds install -f -p passwall2 luci-app-passwall2
./scripts/feeds install -f -p istore luci-app-store
./scripts/feeds install -f -p nas_packages quickstart
./scripts/feeds install -f -p nas_luci luci-app-quickstart
./scripts/feeds install -f -p openclash luci-app-openclash
grep -q 'PKG_VERSION:=26.3.6' feeds/passwall/luci-app-passwall/Makefile
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile
cp custom/device/config.seed .config
make defconfig
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_gielink_g33pro-v1=yfor p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }; done
HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s
' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot
./scripts/diffconfig.sh > build.config
 .config
DTS="target/linux/mediatek/dts/mt7981-gielink-g33pro-v1.dts"
NET="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"
grep -q 'compatible = "mediatek,mt7531";' "$DTS"
grep -q 'label = "lan1";' "$DTS"
grep -q 'label = "lan2";' "$DTS"
grep -q 'label = "lan3";' "$DTS"
grep -q 'phy-handle = <&int_gbe_phy>;' "$DTS"
grep -q 'led-running = &status_green_led;' "$DTS"
grep -q 'gpios = <&pio 10 GPIO_ACTIVE_HIGH>;' "$DTS"
grep -q 'gpios = <&pio 11 GPIO_ACTIVE_HIGH>;' "$DTS"
grep -q 'gpios = <&pio 12 GPIO_ACTIVE_HIGH>;' "$DTS"
grep -q 'ucidef_set_interfaces_lan_wan "lan1 lan2 lan3" "eth1"' "$NET"
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }; done
HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s
' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot
./scripts/diffconfig.sh > build.config
