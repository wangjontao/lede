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
# START=95: after network (S20) and wifi (S19) are up, otherwise "wifi reload"
# fails and the radios keep the stock LEDE configuration.
mkdir -p files/etc/rc.d
rm -f files/etc/rc.d/S20juliang-wifi files/etc/rc.d/K20juliang-wifi
ln -sf ../init.d/juliang-wifi files/etc/rc.d/S95juliang-wifi
ln -sf ../init.d/wan-lease-guard files/etc/rc.d/S95wan-lease-guard

# --- regression guards ----------------------------------------------------
# A build once shipped with no wireless and no LAN address because the
# first-boot script used "set -e" and died before it reached the radio and LAN
# sections. Fail the build loudly if that pattern ever comes back.
if grep -Eq '^[[:space:]]*set -e' files/etc/uci-defaults/99-zz-dulwifi; then
    echo "ERROR: 99-zz-dulwifi must not use 'set -e' (it will abort mid-config)" >&2
    exit 1
fi
[ -f files/etc/init.d/juliang-wifi ] || {
    echo "ERROR: files/etc/init.d/juliang-wifi is missing" >&2
    exit 1
}
[ -L files/etc/rc.d/S95juliang-wifi ] || {
    echo "ERROR: juliang-wifi is not enabled in /etc/rc.d" >&2
    exit 1
}
if grep -Eq "ssid='" files/usr/libexec/dulwifi-firstboot 2>/dev/null; then
    echo "ERROR: dulwifi-firstboot still rewrites SSIDs; JuLiang branding is applied by juliang-wifi" >&2
    exit 1
fi

# Every shell script we ship must at least parse. A single stray CR in
# /etc/board.d/02_network once made board_detect fail, which silently turned the
# LAN into a single eth0 interface and left all four ports dead.
_bad=0
while IFS= read -r f; do
    case "$f" in
        *.sh|*/init.d/*|*/uci-defaults/*|*/libexec/*|*/hotplug.d/*/*|*/board.d/*|*/rc.common) ;;
        *) continue ;;
    esac
    sh -n "$f" 2>/dev/null || { echo "ERROR: shell syntax error in $f" >&2; _bad=1; }
done < <(find files -type f)
[ "$_bad" -eq 0 ] || exit 1

# board.d/02_network must not contain CR characters; OpenWrt parses it with sh.
# It lives in the target tree, not in the overlay, so check the source path too.
for net in files/etc/board.d/02_network \
           target/linux/mediatek/filogic/base-files/etc/board.d/02_network; do
    [ -f "$net" ] || continue
    if grep -q $'\r' "$net"; then
        echo "ERROR: $net contains CR characters" >&2
        exit 1
    fi
    sh -n "$net" 2>/dev/null || { echo "ERROR: $net has a shell syntax error" >&2; exit 1; }
done

# CR characters anywhere in the image definition or the device trees break the
# build in confusing ways: DEVICE_DTS becomes "foo\r", the DTB lookup fails and
# TARGET_DEVICES gets a name the profile system cannot resolve. A whole batch of
# ported devices once carried them after being appended with Windows tooling.
for d in target/linux/mediatek/image target/linux/mediatek/dts \
         target/linux/mediatek/filogic/base-files; do
    [ -d "$d" ] || continue
    if grep -rlq $'\r' "$d" 2>/dev/null; then
        echo "ERROR: CR characters found under $d:" >&2
        grep -rl $'\r' "$d" 2>/dev/null | while read -r bad; do echo "  $bad" >&2; done
        exit 1
    fi
done

# A UTF-8 BOM in front of a device tree makes dtc fail on the first character,
# so the device never gets a DTB. Nine ported DTS files once carried one after
# being written with Windows tooling; strip-BOM regressions must fail here.
for d in target/linux/mediatek/dts target/linux/mediatek/image \
         target/linux/mediatek/filogic/base-files scripts custom; do
    [ -d "$d" ] || continue
    find "$d" -type f 2>/dev/null | while read -r f; do
        if [ "$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
            echo "ERROR: UTF-8 BOM in $f" >&2
            echo "FAILED" >> /tmp/.juliang-bom
        fi
    done
    if [ -f /tmp/.juliang-bom ]; then rm -f /tmp/.juliang-bom; exit 1; fi
done


echo "overlay assembled: $(find files -type f | wc -l) files"
