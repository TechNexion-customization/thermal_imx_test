#!/bin/bash

#################################################################################
# Copyright 2020 Technexion Ltd.
#
# Author: Ray Chang <ray.chang@technexion.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#################################################################################

CPUBURN=no
IPERF_SERVER=10.88.88.88
IPERF_PORT=5201
WIFI_DRV=wlan
IFACE=wlan0

is_ap_connected() {
        for n in {1..30}; do
                if (iwconfig $IFACE | grep -qE 'Link Quality|Security mode|..:..:..:..:..:..'); then
                        return 0
                else
                        usleep 300000
                fi
        done
        return 1
}

is_ipget() {
        for i in {1..20}; do
                ipaddr=$(ifconfig $IFACE | grep inet | grep -v inet6 | cut -d ' ' -f12)
                [ -n "$ipaddr" ] && return 0
                usleep 500000
        done
        return 1
}

led_on() {
        if [ -f /sys/class/leds/status/brightness ]; then
                echo 1 >/sys/class/leds/status/brightness
        elif [ -f /sys/class/leds/gpio-led/brightness ]; then
                echo 1 >/sys/class/leds/gpio-led/brightness
        fi
}

led_off() {
        if [ -f /sys/class/leds/status/brightness ]; then
                echo 0 >/sys/class/leds/status/brightness
        elif [ -f /sys/class/leds/gpio-led/brightness ]; then
                echo 0 >/sys/class/leds/gpio-led/brightness
        fi
}

iperf_test() {
        iperf3 -f k -c "$IPERF_SERVER" -p "$IPERF_PORT" -t 7 -w 320k -P 4 -l 24000 >/tmp/iperflog
}

if [ "$CPUBURN" == "yes" ]; then
        killall stress-ng
fi

led_on

PID_THIS=$$
echo "PID is: $PID_THIS"

macaddr=$(cat /sys/bus/sdio/devices/*/net/$IFACE/address)
mac=${macaddr//:/}
echo "MAC address: $macaddr"

if [ "$CPUBURN" == "yes" ]; then
        stress-ng -c 0 -l 80 &
fi

if (is_ap_connected); then
        if (is_ipget); then
                usleep 100000
                count=0
                samecount=0
                ret=-1
                oldret=-1
                while true; do
                        [ $samecount -lt 5 ] && [ -n "$ret" ] && [ $ret -ne 0 ] && led_on
                        [ $count -eq 1 ] && iperf_test &
                        if [ $count -gt 43 ]; then
                                ret=$(tail -n3 </tmp/iperflog | head -n1 | awk '{printf("%d", $6)}')
                                if [ "$ret" == "$oldret" ]; then samecount=$((samecount + 1)); else samecount=0; fi
                                oldret=$ret
                                [ $samecount -gt 5 ] && ret=0
                                [ $samecount -ge 3 ] && samecount=0 && killall iperf3 && sleep 2 && is_ap_connected && is_ipget && iperf_test &
                                cputmp=$(sed 's/000//' /sys/class/thermal/thermal_zone0/temp)
                                cpufreq=$(sed 's/000//' /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq)
                                timestamp=$(date +"[%D %T]")
                                if [ "$WIFI_DRV" != "wlan" ] && [ "$WIFI_DRV" != "qca9377" ]; then
                                        echo "$timestamp CPU Freq/Temp: $cpufreq MHz/$cputmp ^C, BW: $ret KBits/sec" | tee -a /tmp/wifilog_"$mac"
                                else
                                        chiptmp=$(iwpriv wlan0 get_temp | cut -d : -f2 | tr -d ' ')
                                        wifirssi=$(iwpriv wlan0 getRSSI | cut -d = -f2)
                                        echo "$timestamp CPU Freq/Temp: $cpufreq MHz/$cputmp ^C, WiFi RSSI: $wifirssi, Temp: $chiptmp, BW: $ret KBits/sec" | tee -a /tmp/wifilog_"$mac"
                                fi
                                count=0
                        fi
                        usleep 100000
                        led_off
                        usleep 100000
                        count=$((count + 1))
                done
        fi
fi

led_off

