#!/bin/bash
# Shared overlay assembly for every JuLiang build (single device and matrix).
#
# Produces, inside the build tree:
#   files/            rootfs overlay captured from the running system
#   files/etc/shadow  root password @password@
#
# Called from custom/rax3000m-nand/prepare.sh and scripts/build-juilang-matrix.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

HASH="$(openssl passwd -1 '@password@')"
mkdir -p files
cp package/base-files/files/etc/shadow files/etc/shadow
sed -i "s#^root:[^:]*:#root:${HASH}:#" files/etc/shadow
printf '%s\n' "$HASH" > files/etc/dulwifi-root.hash
chmod 600 files/etc/shadow files/etc/dulwifi-root.hash

# Device overlay captured from the running system.
cp -a custom/rax3000m-nand/files/. files/

for f in etc/init.d/dulwifi-firstboot etc/init.d/juliang-dashboard etc/init.d/juliang-wifi \
         etc/init.d/wan-lease-guard \
         etc/uci-defaults/96-juliang-dashboard etc/uci-defaults/97-wan-guard \
         etc/uci-defaults/99-enable-nps-wan-mac etc/uci-defaults/99-zz-dulwifi \
         etc/hotplug.d/iface/50-arpbind etc/hotplug.d/iface/98-passwall2 \
         etc/hotplug.d/iface/99-fastacl252 etc/hotplug.d/iface/99-mtk-lro \
         etc/hotplug.d/iface/99-nps-wan-mac \
         usr/libexec/dulwifi-firstboot usr/libexec/nps-wan-mac usr/libexec/wan-lease-guard \
         usr/bin/juliang-traffic-daemon usr/bin/juliang-traffic-sample; do
    [ -e "files/$f" ] && chmod 755 "files/$f"
done

# Enable the wireless service in the image itself, so the SSIDs are applied on
# the very first boot without depending on a successful uci-defaults run.
mkdir -p files/etc/rc.d
ln -sf ../init.d/juliang-wifi files/etc/rc.d/S20juliang-wifi
ln -sf ../init.d/wan-lease-guard files/etc/rc.d/S95wan-lease-guard

echo "overlay assembled: $(find files -type f | wc -l) files"
