#!/bin/sh
set -eu

# HY3000 TikTok 10WiFi setup. Existing DulWiFi SSIDs are preserved.
SSID_PREFIX="A"
WIFI_PASSWORD="a1111111"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/tiktok10wifi-backup-${STAMP}"

mkdir -p "$BACKUP_DIR"
for cfg in network dhcp wireless firewall passwall passwall2; do
    [ -f "/etc/config/$cfg" ] && cp -p "/etc/config/$cfg" "$BACKUP_DIR/$cfg"
done

# Remove only sections owned by this script so reruns are safe.
for i in $(seq 1 10); do
    n=$(printf '%02d' "$i")
    uci -q delete "network.tkdev${n}" || true
    uci -q delete "network.tk${n}" || true
    uci -q delete "dhcp.tk${n}" || true
    uci -q delete "wireless.tk_ap${n}" || true
done
for section in tkwifi tk_allow_dhcp tk_allow_dns tk_force_dns tk_block_dot; do
    uci -q delete "firewall.$section" || true
done

for i in $(seq 1 10); do
    n=$(printf '%02d' "$i")
    net="tk${n}"
    dev="tkdev${n}"
    bridge="br-tk${n}"
    gateway="172.16.${i}.1"

    uci set "network.${dev}=device"
    uci set "network.${dev}.name=${bridge}"
    uci set "network.${dev}.type=bridge"
    uci set "network.${dev}.bridge_empty=1"

    uci set "network.${net}=interface"
    uci set "network.${net}.device=${bridge}"
    uci set "network.${net}.proto=static"
    uci set "network.${net}.ipaddr=${gateway}"
    uci set "network.${net}.netmask=255.255.255.0"
    uci set "network.${net}.delegate=0"

    uci set "dhcp.${net}=dhcp"
    uci set "dhcp.${net}.interface=${net}"
    uci set "dhcp.${net}.start=100"
    uci set "dhcp.${net}.limit=100"
    uci set "dhcp.${net}.leasetime=12h"
    uci set "dhcp.${net}.ignore=0"
    uci set "dhcp.${net}.force=1"
    uci set "dhcp.${net}.dhcpv4=server"
    uci set "dhcp.${net}.ra=disabled"
    uci set "dhcp.${net}.dhcpv6=disabled"
    uci set "dhcp.${net}.ndp=disabled"
    uci add_list "dhcp.${net}.dhcp_option=3,${gateway}"
    uci add_list "dhcp.${net}.dhcp_option=6,${gateway}"

    radio="radio1"
    [ "$i" -ge 9 ] && radio="radio0"
    uci set "wireless.tk_ap${n}=wifi-iface"
    uci set "wireless.tk_ap${n}.device=${radio}"
    uci set "wireless.tk_ap${n}.network=${net}"
    uci set "wireless.tk_ap${n}.mode=ap"
    uci set "wireless.tk_ap${n}.ssid=${SSID_PREFIX}${i}"
    uci set "wireless.tk_ap${n}.encryption=psk2+ccmp"
    uci set "wireless.tk_ap${n}.key=${WIFI_PASSWORD}"
    uci set "wireless.tk_ap${n}.disabled=0"
    uci set "wireless.tk_ap${n}.isolate=1"

done

# Isolated zone. Deliberately no forwarding section to wan or lan.
uci set firewall.tkwifi='zone'
uci set firewall.tkwifi.name='tkwifi'
uci set firewall.tkwifi.input='REJECT'
uci set firewall.tkwifi.output='ACCEPT'
uci set firewall.tkwifi.forward='REJECT'
uci set firewall.tkwifi.masq='0'
for i in $(seq 1 10); do
    n=$(printf '%02d' "$i")
    uci add_list "firewall.tkwifi.network=tk${n}"
done

uci set firewall.tk_allow_dhcp='rule'
uci set firewall.tk_allow_dhcp.name='TK-Allow-DHCP'
uci set firewall.tk_allow_dhcp.src='tkwifi'
uci set firewall.tk_allow_dhcp.proto='udp'
uci set firewall.tk_allow_dhcp.dest_port='67'
uci set firewall.tk_allow_dhcp.target='ACCEPT'
uci set firewall.tk_allow_dhcp.family='ipv4'

uci set firewall.tk_allow_dns='rule'
uci set firewall.tk_allow_dns.name='TK-Allow-Router-DNS'
uci set firewall.tk_allow_dns.src='tkwifi'
uci set firewall.tk_allow_dns.proto='tcp udp'
uci set firewall.tk_allow_dns.dest_port='53'
uci set firewall.tk_allow_dns.target='ACCEPT'
uci set firewall.tk_allow_dns.family='ipv4'

# Force all plain DNS to the router. IPv6 is disabled on these ten networks.
uci set firewall.tk_force_dns='redirect'
uci set firewall.tk_force_dns.name='TK-Force-DNS-to-Router'
uci set firewall.tk_force_dns.src='tkwifi'
uci set firewall.tk_force_dns.proto='tcp udp'
uci set firewall.tk_force_dns.src_dport='53'
uci set firewall.tk_force_dns.dest_port='53'
uci set firewall.tk_force_dns.target='DNAT'
uci set firewall.tk_force_dns.family='ipv4'

uci set firewall.tk_block_dot='rule'
uci set firewall.tk_block_dot.name='TK-Block-Direct-DoT'
uci set firewall.tk_block_dot.src='tkwifi'
uci set firewall.tk_block_dot.dest='*'
uci set firewall.tk_block_dot.proto='tcp udp'
uci set firewall.tk_block_dot.dest_port='853'
uci set firewall.tk_block_dot.target='REJECT'
uci set firewall.tk_block_dot.family='ipv4'

uci commit network
uci commit dhcp
uci commit wireless
uci commit firewall

# Replace proxy configuration only after the network configuration is complete.
CONFIG_BUNDLE="/root/tiktok10wifi-files"
if [ ! -s "$CONFIG_BUNDLE/passwall" ] || [ ! -s "$CONFIG_BUNDLE/passwall2" ]; then
    echo "ERROR: missing PassWall configuration files in $CONFIG_BUNDLE" >&2
    exit 1
fi
cp "$CONFIG_BUNDLE/passwall" /etc/config/passwall
cp "$CONFIG_BUNDLE/passwall2" /etc/config/passwall2
chmod 600 /etc/config/passwall /etc/config/passwall2

/etc/init.d/network restart
sleep 8
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
wifi reload

echo "TikTok 10WiFi configured: A1-A8 on 5 GHz, A9-A10 on 2.4 GHz."
echo "Password: ${WIFI_PASSWORD}"
echo "Backups: ${BACKUP_DIR}"
echo "No tkwifi forwarding to WAN was created. User-provided PassWall configurations were installed."
