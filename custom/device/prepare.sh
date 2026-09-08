#!/bin/bash
set -euo pipefail
./scripts/feeds update -a
if ! ./scripts/feeds install -a; then
    echo 'Feed-wide installation reported optional-package dependency warnings; validating requested packages explicitly.'
fi
./scripts/feeds install -f -p passwall luci-app-passwall
./scripts/feeds install -f -p passwall2 luci-app-passwall2
./scripts/feeds install -f -p istore luci-app-store
./scripts/feeds install -f -p nas_packages quickstart
./scripts/feeds install -f -p nas_luci luci-app-quickstart
./scripts/feeds install -f -p openclash luci-app-openclash
NPS_MODEL='feeds/luci/applications/luci-app-nps/luasrc/model/cbi/nps.lua'
test -f "$NPS_MODEL"
sed -i 's/server.datatype = "ipaddr"/server.datatype = "host"/' "$NPS_MODEL"
sed -i 's/Must an IPv4 address/IPv4 address or domain name/' "$NPS_MODEL"
grep -q 'server.datatype = "host"' "$NPS_MODEL"
grep -q 'PKG_VERSION:=26.3.6' feeds/passwall/luci-app-passwall/Makefile
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile
cp custom/device/config.seed .config
make defconfig
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_jcg_q30-pro=y$' .config
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc luci-app-ddns luci-app-nlbwmon luci-app-wol luci-app-vlmcsd; do grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }; done
HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s
' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot
./scripts/diffconfig.sh > build.config
