#!/bin/bash

#################################################################################
# Copyright 2019 Technexion Ltd.
#
# Author: Richard Hu <richard.hu@technexion.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#################################################################################

( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del ) && ( sleep 1 )

( ifconfig | grep -q eth0 ) && ( connmanctl disable ethernet )
echo

printf "Scanning WIFI AP... \n"

connmanctl scan wifi
connmanctl services > /tmp/wifi_log
echo "=========================="
printf "AP in use: \n"
echo "=========================="
(grep AO /tmp/wifi_log) || echo Not connect to AP

echo 
echo "=========================="
printf "List available AP: \n"
echo "=========================="
awk 'FNR == 1 {next} {print $(NF-1)}' /tmp/wifi_log

echo
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
