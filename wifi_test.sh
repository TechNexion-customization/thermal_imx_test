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
NETWORK_MANAGER=connmanctl

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

led_blink() {
        while true; do
                led_on
                usleep 150000
                led_off
                usleep 150000
        done
}

iperf_test() {
        iperf3 -f k -c "$IPERF_SERVER" -p "$IPERF_PORT" -t 8 -w 320k -P 4 -l 24000 >/tmp/iperflog
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

if ( is_ap_connected ); then
        if ( is_ipget ); then
                usleep 100000
                samecount=0
                ret=-1
                oldret=-1
                while true; do
                        if [ $samecount -eq 0 ] && [ -z "$led_blink_pid" ]; then
                                led_blink >/dev/null 2>&1 &
                                led_blink_pid=$!
                        fi
                        if ( is_ap_connected >/dev/null 2>&1 ); then
                                ( is_ipget >/dev/null 2>&1 ) && iperf_test &
                        else
                                if [ "$NETWORK_MANAGER" == connmanctl ]; then
                                        ap=$($NETWORK_MANAGER services | grep "*A " | cut -d' ' -f4)
                                        [ -n "$ap" ] && $NETWORK_MANAGER connect $ap
                                fi
                        fi
                        usleep 9950000
                        ret=$(tail -n3 </tmp/iperflog | head -n1 | awk '{printf("%d", $6)}')
                        if [ "$ret" == "$oldret" ] || [ -z "$ret" ] || [ $ret -eq 0 ]; then samecount=$((samecount + 1)); else samecount=0; fi
                        oldret=$ret
                        if [ $samecount -ge 3 ]; then
                                killall iperf3
                                [ -n "$led_blink_pid" ] && kill $led_blink_pid && led_blink_pid=""
                                ret=0
                        fi
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
                done
        fi
fi

led_off
