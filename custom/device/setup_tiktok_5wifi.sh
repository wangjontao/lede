#!/bin/sh
PASSWORD='a1111111'
for I in $(seq 1 5); do
 N=$(printf '%02d' "$I"); NET="ap${N}"; DEV="apdev${N}"; BR="br-ap${N}"; IP="172.16.${I}.1"
 uci -q delete network.$DEV; uci set network.$DEV='device'; uci set network.$DEV.name="$BR"; uci set network.$DEV.type='bridge'; uci set network.$DEV.bridge_empty='1'
 uci -q delete network.$NET; uci set network.$NET='interface'; uci set network.$NET.device="$BR"; uci set network.$NET.proto='static'; uci set network.$NET.ipaddr="$IP"; uci set network.$NET.netmask='255.255.255.0'; uci set network.$NET.delegate='0'
 uci -q delete dhcp.$NET; uci set dhcp.$NET='dhcp'; uci set dhcp.$NET.interface="$NET"; uci set dhcp.$NET.start='100'; uci set dhcp.$NET.limit='150'; uci set dhcp.$NET.leasetime='12h'; uci set dhcp.$NET.ra='disabled'; uci set dhcp.$NET.dhcpv6='disabled'; uci set dhcp.$NET.ndp='disabled'; uci add_list dhcp.$NET.dhcp_option="3,$IP"; uci add_list dhcp.$NET.dhcp_option="6,$IP"
 RADIO=radio1; [ "$I" -eq 5 ] && RADIO=radio0
 uci -q delete wireless.ap$N; uci set wireless.ap$N='wifi-iface'; uci set wireless.ap$N.device="$RADIO"; uci set wireless.ap$N.network="$NET"; uci set wireless.ap$N.mode='ap'; uci set wireless.ap$N.ssid="A$I"; uci set wireless.ap$N.encryption='psk2+ccmp'; uci set wireless.ap$N.key="$PASSWORD"; uci set wireless.ap$N.disabled='0'; uci set wireless.ap$N.isolate='1'
done
uci -q delete firewall.tkwifi; uci set firewall.tkwifi='zone'; uci set firewall.tkwifi.name='tkwifi'; uci set firewall.tkwifi.input='ACCEPT'; uci set firewall.tkwifi.output='ACCEPT'; uci set firewall.tkwifi.forward='REJECT'
for I in $(seq 1 5); do uci add_list firewall.tkwifi.network="ap$(printf '%02d' "$I")"; done
uci commit network; uci commit dhcp; uci commit wireless; uci commit firewall
[ -f /root/tiktok10wifi-files/passwall ] && { cp -a /etc/config/passwall /etc/config/passwall.bak-5wifi 2>/dev/null || true; cp /root/tiktok10wifi-files/passwall /etc/config/passwall; }
[ -f /root/tiktok10wifi-files/passwall2 ] && { cp -a /etc/config/passwall2 /etc/config/passwall2.bak-5wifi 2>/dev/null || true; cp /root/tiktok10wifi-files/passwall2 /etc/config/passwall2; }
/etc/init.d/network restart; sleep 8; /etc/init.d/dnsmasq restart; /etc/init.d/firewall restart; wifi reload
