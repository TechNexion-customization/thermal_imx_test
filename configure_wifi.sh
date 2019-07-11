#!/bin/sh

( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del )
( ifconfig | grep -q eth0 ) && ( connmanctl disable ethernet )
echo

printf "Scanning WIFI AP... \n"

connmanctl scan wifi
connmanctl services > /tmp/wifi_log
echo ==========================
printf "AP in use: \n"
echo ==========================
(cat /tmp/wifi_log | grep AO) || echo Not connect to AP

echo 
echo ==========================
printf "List available AP: \n"
echo ==========================
cat /tmp/wifi_log | awk 'FNR == 1 {next} {print $(NF-1)}'

read -p "Please select the AP that you want to connect: " AP_NANE
read -p "Please enther passphrase: " PASSWORD
cat << EOF > /var/lib/connman/test.config
[service_${AP_NANE}]
Type = wifi
Name = ${AP_NANE}
Passphrase = ${PASSWORD}
IPv4.method = dhcp
IPv6.method = auto
IPv6.privacy = disabled
EOF

systemctl restart connman.service
