#!/bin/sh
# JuLiang Live OS: single dual-band guest/live network on br-live.
# Replaces the 5-AP layout created by setup_tiktok_5wifi.sh.
# PSK: keeps the existing Live-* key when present, otherwise uses LIVE_PSK below.

LIVE_PSK='a1111111'
NET='jfa25w1'
DEV='live_dev'
BR='br-live'
IP='172.16.1.1'

existing_key() {
    uci -q get wireless.live5g.key 2>/dev/null || uci -q get wireless.live24.key 2>/dev/null || true
}
KEY="$(existing_key)"
[ -n "$KEY" ] || KEY="$LIVE_PSK"

# --- network: bridge + static interface ---
uci -q delete network.$DEV
uci set network.$DEV='device'
uci set network.$DEV.name="$BR"
uci set network.$DEV.type='bridge'
uci set network.$DEV.bridge_empty='1'

uci -q delete network.$NET
uci set network.$NET='interface'
uci set network.$NET.device="$BR"
uci set network.$NET.proto='static'
uci set network.$NET.ipaddr="$IP"
uci set network.$NET.netmask='255.255.255.0'
uci set network.$NET.delegate='0'

# --- dhcp: pool .100-.249, DNS and gateway pinned to the bridge ---
uci -q delete dhcp.$NET
uci set dhcp.$NET='dhcp'
uci set dhcp.$NET.interface="$NET"
uci set dhcp.$NET.start='100'
uci set dhcp.$NET.limit='150'
uci set dhcp.$NET.leasetime='12h'
uci set dhcp.$NET.ra='disabled'
uci set dhcp.$NET.dhcpv6='disabled'
uci set dhcp.$NET.ndp='disabled'
uci add_list dhcp.$NET.dhcp_option="3,$IP"
uci add_list dhcp.$NET.dhcp_option="6,$IP"

# --- wifi: two SSIDs, one per radio ---
uci -q delete wireless.live5g
uci set wireless.live5g='wifi-iface'
uci set wireless.live5g.device='radio1'
uci set wireless.live5g.network="$NET"
uci set wireless.live5g.mode='ap'
uci set wireless.live5g.ssid='Live-5G'
uci set wireless.live5g.encryption='psk2+ccmp'
uci set wireless.live5g.key="$KEY"
uci set wireless.live5g.disabled='0'
uci set wireless.live5g.isolate='1'

uci -q delete wireless.live24
uci set wireless.live24='wifi-iface'
uci set wireless.live24.device='radio0'
uci set wireless.live24.network="$NET"
uci set wireless.live24.mode='ap'
uci set wireless.live24.ssid='Live-2.4G'
uci set wireless.live24.encryption='psk2+ccmp'
uci set wireless.live24.key="$KEY"
uci set wireless.live24.disabled='0'
uci set wireless.live24.isolate='1'

# --- firewall: dedicated zone for the live bridge ---
uci -q delete firewall.$NET
uci set firewall.$NET='zone'
uci set firewall.$NET.name="$NET"
uci set firewall.$NET.input='ACCEPT'
uci set firewall.$NET.output='ACCEPT'
uci set firewall.$NET.forward='REJECT'
uci add_list firewall.$NET.network="$NET"

uci commit network
uci commit dhcp
uci commit wireless
uci commit firewall

# --- optional proxy config restored from the image ---
[ -f /root/live-wifi-files/passwall2 ] && {
    cp -a /etc/config/passwall2 /etc/config/passwall2.bak-live 2>/dev/null || true
    cp /root/live-wifi-files/passwall2 /etc/config/passwall2
}

/etc/init.d/network restart
sleep 8
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart
wifi reload
