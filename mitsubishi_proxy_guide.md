# Mitsubishi Outlander PHEV Wi-Fi Meter-Cupboard Proxy Deployment Guide

This guide details the deployment of a transparent Wi-Fi proxy for the Mitsubishi Outlander PHEV (2018, 2.0L) using a GL-iNet GL-AR150-ext router running OpenWrt. It resolves deep signal attenuation issues from the driveway to the house, allowing the official remote control app to function flawlessly binnenshuis.

*NOTE:* In order for this setup to work, the router has to downgrade it's security for the client to wpa-psk tkip (which is not very secure). The access to REMOTE-MITS is still protected by WPA2-PSK/WPA3-PSK CCMP-AES but the communication between the router and the car is not that well protected.
Make sure you connect the router to a "guest" port of your main-router so there's no risk of accessing your internal network!!!

## Architecture & Network Design

*   **RF Carrier Clamping (Channel 3):** The vehicle's Wi-Fi module operates strictly on Channel 3 (2.4GHz, 20MHz bandwidth, legacy 802.11b/g modes). The proxy locks the radio module onto this frequency.
*   **IP Overlap Mitigation via /32 Host-Routing:** Both the phone hotspot (`wlan0`) and the vehicle client (`wlan2`) exist within the `192.168.8.X` segment. To prevent a routing deadlock, a highly specific Host Route (`255.255.255.255`) is bound to `wlan2`, forcing vehicle-destined traffic (`192.168.8.46`) to bypass general tables and egress through the correct interface [1.1].
*   **The Magic Layer (Proxy ARP):** No Network Address Translation (NAT) or Masquerading is used. The Linux kernel intercepts and handles ARP requests transparently across both interfaces using `proxy_arp=1` [^3]. The smartphone app communicates seamlessly as if it were connected directly to the vehicle's oprit Wi-Fi.

---

## Step-by-Step Deployment Commands (UCI Registry)

Log into your GL-AR150 router via SSH as root (default: `192.168.1.1` after a fresh OpenWrt factory flash) and execute the following configuration blocks.

### Block 1: Hostname Inception & Inbound WAN Management
This block renames the node, opens firewall access for remote management from your home network, and migrates the default LAN interface to ensure the `192.168.8.X` range is fully dedicated to the vehicle proxy architecture [1.1, 1.2].

```bash
# Set the system hostname internally
uci set system.@system.hostname='mbpiz-rtr'

# Enforce the physical WAN port to broadcast this hostname via DHCP
uci set network.wan.hostname='mbpiz-rtr'

# Move factory LAN interface to prevent subnet collisions with the vehicle range
uci set network.lan.ipaddr='192.168.1.1'

# Configure WAN firewall zone to ACCEPT incoming traffic for local management
uci set firewall.@zone[1].input='ACCEPT'
uci set firewall.@zone[1].forward='ACCEPT'

# Add an explicit firewall rule allowing incoming SSH (22) and Web UI (80) via WAN
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-Admin-via-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22 80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

# Force the SSH dropbear daemon to listen globally across all active interfaces
uci set dropbear.@dropbear.Interface=''

# Commit changes to non-volatile flash storage
uci commit system
uci commit network
uci commit firewall
uci commit dropbear
```

### Block 2: Interface Inception & Overlap Routing
This block establishes the two logical wireless network bridges and deploys the essential `/32` Host Route targeting the vehicle's hard-coded IP address (`.46`) [1.1].

```bash
# Instantiate the local Hotspot interface inside a strict /27 boundary
uci set network.mitsubishi_ap=interface
uci set network.mitsubishi_ap.proto='static'
uci set network.mitsubishi_ap.ipaddr='192.168.8.50'
uci set network.mitsubishi_ap.netmask='255.255.255.224'
uci set network.mitsubishi_ap.device='wlan0'

# Instantiate the Vehicle Client interface within a standard broad /24 boundary
uci set network.mitsubishi_client=interface
uci set network.mitsubishi_client.proto='static'
uci set network.mitsubishi_client.ipaddr='192.168.8.49'
uci set network.mitsubishi_client.netmask='255.255.255.0'
uci set network.mitsubishi_client.device='wlan2'

# Enforce the highly critical /32 Host Route mapping for vehicle communication priority
uci set network.car_route=route
uci set network.car_route.interface='mitsubishi_client'
uci set network.car_route.target='192.168.8.46'
uci set network.car_route.netmask='255.255.255.255'

uci commit network
```

### Block 3: Micro-Subnet DHCP Architecture
This block configures `dnsmasq` to hand out dynamic IP addresses to your iPhone. In OpenWrt, `option start` represents a numerical network offset, not a literal IP [1.2].

```bash
# Bind the DHCP allocation daemon to the mitsubishi_ap interface layout
uci set dhcp.mitsubishi_ap=dhcp
uci set dhcp.mitsubishi_ap.interface='mitsubishi_ap'

# Calculation: Base Network Address (.32) + Offset Variable (19) = Start Lease at .51
uci set dhcp.mitsubishi_ap.start='19'
uci set dhcp.mitsubishi_ap.limit='12'
uci set dhcp.mitsubishi_ap.leasetime='12h'

# Pass the gateway IP and push the meter-cupboard DNS target server to the client
uci add_list dhcp.mitsubishi_ap.dhcp_option='3,192.168.8.50'
uci add_list dhcp.mitsubishi_ap.dhcp_option='6,192.168.200.12'

uci commit dhcp
```

### Block 4: Wireless Chipset Splitting & Credentials
This block configures the internal Atheros radio module. It unlocks the hardware channels, configures your custom local hotspot, and initiates the legacy background link to the vehicle [1.1, 5].

```bash
# Enable the primary radio chipset and bind global hardware parameters
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='3'
uci set wireless.radio0.hwmode='11g'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.country='00' # Global region code bypasses regional channel blockouts

# Deploy the local smartphone Hotspot interface (AP Mode)
uci set wireless.default_radio0=wifi-iface
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='mitsubishi_ap'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='REMOTE-MITS'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='<remotemits-secretkey>'
uci set wireless.default_radio0.ifname='wlan0'

# Deploy the passive Outlander attachment link (STA Mode)
uci set wireless.wifinet2=wifi-iface
uci set wireless.wifinet2.device='radio0'
uci set wireless.wifinet2.network='mitsubishi_client'
uci set wireless.wifinet2.mode='sta'
uci set wireless.wifinet2.ssid='REMOTE<mitsunishi-ssid>'
uci set wireless.wifinet2.key='<mitsubishi-secretkey>'
uci set wireless.wifinet2.encryption='psk-mixed'
uci set wireless.wifinet2.ifname='wlan2'
uci set wireless.wifinet2.scan_ssid='1'
uci set wireless.wifinet2.disassoc_low_ack='0'

uci commit wireless
```

### Block 5: Transparent Firewall Infrastructure
This block groups both wireless interfaces inside a single firewall zone, opening all communication lanes natively while keeping network masking (NAT) explicitly disabled [1.2].

```bash
# Group both proxy boundaries into a unified firewall zone
uci set firewall.mitsubishi=zone
uci set firewall.mitsubishi.name='mitsubishi'
uci add_list firewall.mitsubishi.network='mitsubishi_client'
uci add_list firewall.mitsubishi.network='mitsubishi_ap'

# Unshackle inbound, outbound, and inter-zone packet passage rules
uci set firewall.mitsubishi.input='ACCEPT'
uci set firewall.mitsubishi.output='ACCEPT'
uci set firewall.mitsubishi.forward='ACCEPT'
uci set firewall.mitsubishi.masq='0' # Pure transparency mapping without NAT translation

uci commit firewall
```

### Block 6: Kernel Register Modification & Execution
This block injects the Proxy ARP directives into the core Linux file system, forcing the engine to shadow and proxy Layer-2 lookup frames natively [^3].

```bash
# Purge older lines and append Proxy ARP parameters directly into the sysctl core configuration
sed -i '/proxy_arp/d' /etc/sysctl.conf
echo "net.ipv4.conf.wlan0.proxy_arp=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.wlan2.proxy_arp=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.proxy_arp=1" >> /etc/sysctl.conf

# Force system configurations to load kernel flags and reboot subsystems cleanly
sysctl -p
/etc/init.d/system restart
/etc/init.d/network restart
/etc/init.d/firewall restart 2>/dev/null || /etc/init.d/fw4 restart
/etc/init.d/dropbear restart
wifi reload
wifi up radio0
```
