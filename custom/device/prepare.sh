#!/bin/bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_grep() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  grep -q -- "$pattern" "$file" || fail "$label"
  echo "OK: $label"
}

./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -f -p passwall luci-app-passwall
./scripts/feeds install -f -p passwall2 luci-app-passwall2
./scripts/feeds install -f -p istore luci-app-store
./scripts/feeds install -f -p nas_packages quickstart
./scripts/feeds install -f -p nas_luci luci-app-quickstart
./scripts/feeds install -f -p openclash luci-app-openclash

require_grep 'PKG_VERSION:=26.3.6' feeds/passwall/luci-app-passwall/Makefile "Passwall 26.3.6"
require_grep 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile "Passwall2 26.3.5"

cp custom/device/config.seed .config
make defconfig

require_grep '^CONFIG_TARGET_mediatek_filogic_DEVICE_gielink_g33pro-v1=y$' .config "G33Pro target selected"

DTS="target/linux/mediatek/dts/mt7981-gielink-g33pro-v1.dts"
NET="target/linux/mediatek/filogic/base-files/etc/board.d/02_network"

require_grep 'compatible = "mediatek,mt7531";' "$DTS" "MT7531 DSA switch"
require_grep 'label = "lan1";' "$DTS" "LAN1 DSA port"
require_grep 'label = "lan2";' "$DTS" "LAN2 DSA port"
require_grep 'label = "lan3";' "$DTS" "LAN3 DSA port"
require_grep 'label = "lan4";' "$DTS" "LAN4 DSA port"
require_grep 'gmac1: mac@1' "$DTS" "stock standalone WAN gmac1"
require_grep 'port@0 {' "$DTS" "stock LAN1 switch port"
require_grep 'port@3 {' "$DTS" "stock LAN4 switch port"
require_grep 'macaddr_wan: macaddr@a0024' "$DTS" "Q30 Pro WAN MAC offset 0xa0024"
require_grep 'macaddr_lan: macaddr@a002a' "$DTS" "Q30 Pro LAN MAC offset 0xa002a"
require_grep 'led-running = &status_green_led;' "$DTS" "running LED mapped to green"
require_grep 'gpios = <&pio 8 GPIO_ACTIVE_HIGH>;' "$DTS" "stock red LED GPIO8"
require_grep 'gpios = <&pio 13 GPIO_ACTIVE_LOW>;' "$DTS" "stock green LED GPIO13"
require_grep 'reg = <0x580000 0x7000000>;' "$DTS" "Q30Pro 112MiB raw UBI layout"
require_grep 'ucidef_set_interfaces_lan_wan "lan1 lan2 lan3 lan4" eth1' "$NET" "stock 4LAN plus eth1 WAN mapping"

for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do
  grep -q "^CONFIG_PACKAGE_${p}=y$" .config || fail "Required package missing: $p"
  echo "OK: package $p"
done

HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s\n' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot

./scripts/diffconfig.sh > build.config
echo "G33Pro source/config validation passed."
