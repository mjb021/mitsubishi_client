#!/bin/sh
# Dedicated Configuration Restore Script for the GL-AR150 Mitsubishi Proxy
# Optimized strictly for OpenWrt UCI flat-files.

set -e

BACKUP_FILE="/tmp/mitsubishi_proxy_config_backup.tar.gz"

echo "============================================="
echo " Commencing Mitsubishi Proxy State Restore"
echo "============================================="

# Verify that the backup file exists before destroying active state
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file $BACKUP_FILE not found in /tmp!" >&2
    exit 1
fi

echo "[RESTORE PROCESS] Extracting configuration archives to root filesystem..."
# Extract the tarball directly into the root directory to overwrite system files
tar -xzf "$BACKUP_FILE" -C /

echo "[RESTORE PROCESS] Reloading system registers and kernel parameters..."
# Apply kernel parameters immediately
sysctl -p

# Force system configurations to load flags and restart network subsystems cleanly
/etc/init.d/system restart
/etc/init.d/network restart
/etc/init.d/dnsmasq restart
/etc/init.d/firewall restart 2>/dev/null || /etc/init.d/fw4 restart
/etc/init.d/dropbear restart

# Trigger wireless radio interfaces to spin up securely
wifi reload
wifi up radio0

echo "============================================="
echo " Restore completed successfully!"
echo " System is now up and running with proxy configurations."
echo "============================================="
