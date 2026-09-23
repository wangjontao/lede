#!/bin/bash
set -euo pipefail
./scripts/feeds update -a
./scripts/feeds install -a
./scripts/feeds install -f -p passwall luci-app-passwall
./scripts/feeds install -f -p passwall2 luci-app-passwall2
./scripts/feeds install -f -p istore luci-app-store
./scripts/feeds install -f -p nas_packages quickstart
./scripts/feeds install -f -p nas_luci luci-app-quickstart

# OpenClash is fetched as a pinned archive instead of a full git feed.
# This avoids long-running GitHub pack downloads that can terminate with early EOF.
rm -rf package/luci-app-openclash package/feeds/luci/luci-app-openclash /tmp/openclash /tmp/openclash.tar.gz
curl -fL --retry 8 --retry-delay 3 --retry-all-errors --connect-timeout 20 \
  "https://codeload.github.com/vernesong/OpenClash/tar.gz/c3a33c1d3407956fdf8f0e0b7c1a4c52e6ad9593" \
  -o /tmp/openclash.tar.gz
mkdir -p /tmp/openclash
tar -xzf /tmp/openclash.tar.gz --strip-components=1 -C /tmp/openclash
cp -a /tmp/openclash/luci-app-openclash package/
test -f package/luci-app-openclash/Makefile
grep -q 'PKG_VERSION:=26.3.6' feeds/passwall/luci-app-passwall/Makefile
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile
cp custom/device/config.seed .config
make defconfig
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_konka_komi-a31=y$' .config
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }; done
HASH="$(openssl passwd -1 '@password@')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s
' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot
./scripts/diffconfig.sh > build.config
