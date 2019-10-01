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
    echo -e "\t 1. CPU(default:60% load) + memtester + GPU + WIFI stress test"
    echo -e "\t 1. CPU(default:60% load) + memtester + GPU stress test"
    echo -e "\t 2. CPU stress test (stress-ng)"
    echo -e "\t 3. GPU stress test (glmark2)"
    echo -e "\t 4. Video playback test"
    echo -e "\t 5. WIFI throughput stress test(iperf)"
    echo -e "\t 6. WIFI configuration"
    echo -e "\t 7. CPU + WIFI throughput stress test"
    echo
    echo -e "\t Enter your choice: "
    read -n 1 option
}

while [ 1 ]
do
    menu
    echo
    case $option in
    0)
        exit ;;
    1)
        ${EXEC_PATH}/thermal_cpu_mem_gpu_wifi.sh
        ;;
    1)
        ${EXEC_PATH}/thermal_cpu_mem_gpu.sh
        ;;
    2)
        ${EXEC_PATH}/thermal_cpu.sh
        ;;
    3)
        ${EXEC_PATH}/thermal_gpu.sh
        ;;
    4)
        ${EXEC_PATH}/thermal_vpu.sh
        ;;
    5)
        ${EXEC_PATH}/thermal_wifi.sh
        ;;
    6)
        ${EXEC_PATH}/configure_wifi.sh
        ;;
    7)
        ${EXEC_PATH}/thermal_cpu_wifi.sh
        ;;
    *)
        clear
        echo "Wrong selection!!!" ;;
    esac
    echo -en "\n\n\t\tHit any key to continue"
    echo
    read -n 1 option 
done
clear
