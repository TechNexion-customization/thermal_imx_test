#!/bin/sh

#################################################################################
# Copyright 2019 Technexion Ltd.
#
# Author: Richard Hu <richard.hu@technexion.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#################################################################################

echo $(readlink -f "$0")
EXEC_PATH=$(dirname $0)

function menu {
    echo
    echo -e "\t Thermal Stress Test Menu \n"
    echo -e "\t 0. Quit menu"
    echo -e "\t 1. CPU stress test (stress-ng)"
    echo -e "\t 2. GPU stress test (glmark2)"
    echo -e "\t 3. Video playback test"
    echo -e "\t 4. WIFI throughput stress test(iperf)"
    echo -e "\t 5. WIFI configuration"
    echo -e "\t 6. CPU + WIFI throughput stress test"
    echo
    echo -e "\t Enter your choice:" 
    read -n 1 option
}

while [ 1 ]
do
    menu
    case $option in
    0)
        exit ;;
    1)
        ${EXEC_PATH}/thermal_cpu.sh
        ;;
    2)
        ${EXEC_PATH}/thermal_gpu.sh
        ;;
    3)
        ${EXEC_PATH}/thermal_vpu.sh
        ;;
    4)  
        ${EXEC_PATH}/thermal_wifi.sh
        ;;
    5)
        ${EXEC_PATH}/configure_wifi.sh
        ;;
    *)
        clear
        echo "Wrong selection!!!" ;;
    esac
    echo -en "\n\n\t\tHit any key to continue"
    read -n 1 option 
done
clear
