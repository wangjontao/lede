#!/bin/bash
set -euo pipefail
./scripts/feeds update -a
./scripts/feeds install -a
# Force only the requested versions over the ordinary LuCI feed copies.
./scripts/feeds install -f -p passwall2 luci-app-passwall2
./scripts/feeds install -f -p istore luci-app-store
./scripts/feeds install -f -p nas_packages quickstart
./scripts/feeds install -f -p nas_luci luci-app-quickstart
grep -q 'PKG_VERSION:=26.3.5' feeds/passwall2/luci-app-passwall2/Makefile
grep -q 'PKG_RELEASE:=1' feeds/passwall2/luci-app-passwall2/Makefile
cp custom/rax3000m-nand/config.seed .config
make defconfig
grep -q '^CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m-nand=y$' .config
for p in kmod-mt7915e kmod-mt7981-firmware luci-app-passwall2 luci-app-homeproxy luci-app-store quickstart luci-app-quickstart luci-theme-argon luci-app-ttyd luci-app-nps npc; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "Required package missing: $p"; exit 1; }
done
# Streaming QoS: fail the build instead of silently producing an image without cake.
for p in tc kmod-sched-core kmod-sched-cake kmod-ifb sqm-scripts luci-app-sqm; do
    grep -q "^CONFIG_PACKAGE_${p}=y$" .config || { echo "SQM package missing: $p"; exit 1; }
done
HASH="$(openssl passwd -1 'password')"
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s\n' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash
chmod 755 files/etc/uci-defaults/99-zz-dulwifi files/etc/init.d/dulwifi-firstboot files/usr/libexec/dulwifi-firstboot

mkdir -p files/root/live-wifi-files files/etc/init.d files/etc/rc.d
cp custom/device/setup_live_wifi.sh files/root/setup_live_wifi.sh
cp custom/device/passwall2 files/root/live-wifi-files/passwall2
chmod 700 files/root/setup_live_wifi.sh
chmod 600 files/root/live-wifi-files/passwall2
cat > files/etc/init.d/live-wifi-firstboot <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
start() {
    [ -e /etc/live-wifi.done ] && return 0
    (
        sleep 60
        if /root/setup_live_wifi.sh >>/root/live-wifi.log 2>&1; then
            touch /etc/live-wifi.done
            /etc/init.d/live-wifi-firstboot disable
        fi
    ) &
}
EOF
chmod 755 files/etc/init.d/live-wifi-firstboot
ln -sf ../init.d/live-wifi-firstboot files/etc/rc.d/S99live-wifi-firstboot
./scripts/diffconfig.sh > build.config
for feed in feeds/*/.git; do [ -d "$feed" ] && printf '%s %s\n' "$feed" "$(git -C "${feed%/.git}" rev-parse HEAD)"; done > feeds.lock.actual
