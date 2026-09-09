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
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_qihoo_360t7=y$' .config
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall luci-app-passwall2 luci-app-homeproxy luci-app-openclash luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }; done
HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s
' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot
mkdir -p files/root/tiktok5wifi-files files/etc/init.d files/etc/rc.d
cp custom/device/setup_tiktok_5wifi.sh files/root/setup_tiktok_5wifi.sh
cp custom/device/passwall files/root/tiktok5wifi-files/passwall
cp custom/device/passwall2 files/root/tiktok5wifi-files/passwall2
chmod 700 files/root/setup_tiktok_5wifi.sh
chmod 600 files/root/tiktok5wifi-files/passwall files/root/tiktok5wifi-files/passwall2
cat > files/etc/init.d/tiktok5wifi-firstboot <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
start() {
    [ -e /etc/tiktok5wifi.done ] && return 0
    (
        sleep 60
        if /root/setup_tiktok_5wifi.sh >>/root/tiktok5wifi.log 2>&1; then
            cp -a /etc/config/passwall /etc/config/passwall.before-5wifi 2>/dev/null || true
            cp -a /etc/config/passwall2 /etc/config/passwall2.before-5wifi 2>/dev/null || true
            cp /root/tiktok5wifi-files/passwall /etc/config/passwall
            cp /root/tiktok5wifi-files/passwall2 /etc/config/passwall2
            touch /etc/tiktok5wifi.done
            /etc/init.d/tiktok5wifi-firstboot disable
        fi
    ) &
}
EOF
chmod 755 files/etc/init.d/tiktok5wifi-firstboot
ln -sf ../init.d/tiktok5wifi-firstboot files/etc/rc.d/S99tiktok5wifi-firstboot
./scripts/diffconfig.sh > build.config
