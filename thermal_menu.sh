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

echo
readlink -f "$0"
EXEC_PATH=$(dirname "$0")

function menu {
    echo
    echo -e "\t Thermal Stress Test Menu \n"
    echo -e "\t 0. Quit menu"
    echo -e "\t 1. CPU(50%) + memtester(5%) + GPU(5%) + WIFI stress test"
    echo -e "\t 2. CPU(50%) + memtester(5%) + GPU(5%) stress test"
    echo -e "\t 3. CPU stress test (100%)"
    echo -e "\t 4. GPU stress test (100%)"
    echo -e "\t 5. Memory stress test (100%)"
    echo -e "\t 6. Video playback test"
    echo -e "\t 7. WIFI configuration"
    echo -e "\t 8. WIFI throughput stress test(iperf)"
    echo -e "\t 9. CPU(100%) + WIFI throughput stress test"
    echo
    echo -e "\t Enter your choice: "
    read -n 1 option
}

while true
do
    menu
    echo
    case $option in
    0)
        exit ;;
    1)
        "${EXEC_PATH}"/thermal_cpu_mem_gpu_wifi.sh
        ;;
    2)
        "${EXEC_PATH}"/thermal_cpu_mem_gpu.sh
        ;;
    3)
        "${EXEC_PATH}"/thermal_cpu.sh
        ;;
    4)
        "${EXEC_PATH}"/thermal_gpu.sh
        ;;
    5)
        "${EXEC_PATH}"/thermal_mem.sh
        ;;
    6)
        "${EXEC_PATH}"/thermal_vpu.sh
        ;;
    7)
        "${EXEC_PATH}"/configure_wifi.sh
        ;;
    8)
        "${EXEC_PATH}"/thermal_wifi.sh
        ;;
    9)
        "${EXEC_PATH}"/thermal_cpu_wifi.sh
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
