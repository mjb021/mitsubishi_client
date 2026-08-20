#!/bin/sh
# -----------------------------------------------------------------------------
# Mitsubishi Proxy OpenWrt Configuration Backup Script
# Target Hostname: mbpiz-rtr
# -----------------------------------------------------------------------------

BACKUP_DIR="/tmp"
BACKUP_FILE="${BACKUP_DIR}/mitsubishi_proxy_config_backup.tar.gz"

echo "=== Starten Mitsubishi Proxy Config Back-up ==="

# 1. Controleer of we op OpenWrt draaien
if [ ! -f /etc/config/network ]; then
    echo "Fout: Dit script moet rechtstreeks op de OpenWrt-router worden uitgevoerd!"
    exit 1
fi

echo "-> Verzamelen van de UCI-configuratiebestanden..."

# 2. Maak een tijdelijke mappenstructuur aan voor de verzameling
TEMP_STAGE="/tmp/proxy_backup_stage"
rm -rf "${TEMP_STAGE}"
mkdir -p "${TEMP_STAGE}/uci"
mkdir -p "${TEMP_STAGE}/kernel"

# 3. Kopieer de specifieke configuratiebestanden die we hebben aangepast
cp /etc/config/network "${TEMP_STAGE}/uci/"
cp /etc/config/wireless "${TEMP_STAGE}/uci/"
cp /etc/config/dhcp "${TEMP_STAGE}/uci/"
cp /etc/config/firewall "${TEMP_STAGE}/uci/"
cp /etc/config/system "${TEMP_STAGE}/uci/"
cp /etc/config/dropbear "${TEMP_STAGE}/uci/"

# 4. Kopieer de sysctl kernel parameters (waar de Proxy ARP flags in staan)
cp /etc/sysctl.conf "${TEMP_STAGE}/kernel/"

echo "-> Archiveren en comprimeren van de bestanden naar .tar.gz format..."

# 5. Comprimeer de bestanden naar het uiteindelijke archiefbestand in /tmp
cd "${TEMP_STAGE}" || return 1
tar -czf "${BACKUP_FILE}" uci kernel

# 6. Ruim de tijdelijke staging map netjes op
rm -rf "${TEMP_STAGE}"

echo "================================================================="
echo "Back-up succesvol afgerond!"
echo "Bestandslocatie op de router: ${BACKUP_FILE}"
echo "================================================================="
echo ""
echo "Je kunt dit back-up bestand nu downloaden naar je eigen computer."
echo "Open een terminal op je laptop/PC en voer het volgende commando uit:"
echo "scp root@mbpiz-rtr.local:${BACKUP_FILE} ./"
echo "================================================================="