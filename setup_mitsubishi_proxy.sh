#!/bin/sh
# Dedicated Setup Script for the Mitsubishi Outlander PHEV Proxy
# Tailored strictly for OpenWrt (GL-AR150) configurations.

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be executed as root!" >&2
    exit 1
fi

echo "============================================="
echo " Starting Mitsubishi Proxy System Deployment"
echo "============================================="

# 1. System Hostname & WAN Access Enforcement
uci set system.@system.hostname='mbpiz-rtr'
uci set network.wan.hostname='mbpiz-rtr'
uci set network.lan.ipaddr='192.168.1.1' 
uci set firewall.@zone[1].input='ACCEPT'  
uci set firewall.@zone[1].forward='ACCEPT'
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Admin-via-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22 80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set dropbear.@dropbear.Interface=''

# 2. Network Topology & Overlap /32 Route Configuration
uci set network.mitsubishi_ap=interface
uci set network.mitsubishi_ap.proto='static'
uci set network.mitsubishi_ap.ipaddr='192.168.8.50'
uci set network.mitsubishi_ap.netmask='255.255.255.224' 
uci set network.mitsubishi_ap.device='wlan0'

uci set network.mitsubishi_client=interface
uci set network.mitsubishi_client.proto='static'
uci set network.mitsubishi_client.ipaddr='192.168.8.49'
uci set network.mitsubishi_client.netmask='255.255.255.0'  
uci set network.mitsubishi_client.device='wlan2'

uci set network.car_route=route
uci set network.car_route.interface='mitsubishi_client'
uci set network.car_route.target='192.168.8.46'
uci set network.car_route.netmask='255.255.255.255'      

# 3. DHCP Micro-Pool Matrix Setup
uci set dhcp.mitsubishi_ap=dhcp
uci set dhcp.mitsubishi_ap.interface='mitsubishi_ap'
uci set dhcp.mitsubishi_ap.start='19'
uci set dhcp.mitsubishi_ap.limit='12'
uci set dhcp.mitsubishi_ap.leasetime='12h'
uci add_list dhcp.mitsubishi_ap.dhcp_option='3,192.168.8.50'
uci add_list dhcp.mitsubishi_ap.dhcp_option='6,192.168.200.12'

# 4. Wireless Driver Layer Lock down (Channel 3 lock)
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='3'
uci set wireless.radio0.hwmode='11g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.country='00' 

# Deployment of REMOTE-MITS Hotspot
uci set wireless.default_radio0=wifi-iface
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='mitsubishi_ap'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='REMOTE-MITS'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='<remotemits-secretkey>'
uci set wireless.default_radio0.ifname='wlan0'

# Attachment to Outlander Transceiver
uci set wireless.wifinet2=wifi-iface
uci set wireless.wifinet2.device='radio0'
uci set wireless.wifinet2.network='mitsubishi_client'
uci set wireless.wifinet2.mode='sta'
uci set wireless.wifinet2.ssid='REMOTE<mitsubishi-ssid>'
uci set wireless.wifinet2.key='<mitsubishi-secretkey>'
uci set wireless.wifinet2.encryption='psk-mixed'
uci set wireless.wifinet2.ifname='wlan2'
uci set wireless.wifinet2.scan_ssid='1'
uci set wireless.wifinet2.disassoc_low_ack='0'

# 5. Non-NAT Firewall Zone Aggregation
uci set firewall.mitsubishi=zone
uci set firewall.mitsubishi.name='mitsubishi'
uci add_list firewall.mitsubishi.network='mitsubishi_client'
uci add_list firewall.mitsubishi.network='mitsubishi_ap'
uci set firewall.mitsubishi.input='ACCEPT'
uci set firewall.mitsubishi.output='ACCEPT'
uci set firewall.mitsubishi.forward='ACCEPT'
uci set firewall.mitsubishi.masq='0'

# Commit parameters securely
uci commit system; uci commit network; uci commit dhcp; uci commit wireless; uci commit firewall

# 6. Injection of Proxy ARP Kernel Parameters
sed -i '/proxy_arp/d' /etc/sysctl.conf
echo "net.ipv4.conf.wlan0.proxy_arp=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.wlan2.proxy_arp=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.proxy_arp=1" >> /etc/sysctl.conf
sysctl -p

# Force configuration deployment
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
wifi reload
wifi up radio0

echo ">>> SUCCESS: Mitsubishi Proxy deployed smoothly!"
