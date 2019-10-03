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


# Parameter: 1. CPU_LOAD(Optional. Without this parameter, It runs at full-load.)
# Return: PID of stress-ng
cpu_burn()
{
    if [ -z "$1" ]; then
        # Run CPU stress test with full-load
        ( stress-ng -c "$(nproc)" > /dev/null ) &
        if [ $? -eq 0 ]; then
            echo "$!"
        else
            echo "stress-ng fails to start!!!" | tee -a "$LOG"
            echo "0"
        fi
    else
        # Run CPU stress test with specific load
        ( stress-ng -c "$(nproc)" -l "$1" > /dev/null ) &
        if [ $? -eq 0 ]; then
            echo "$!"
        else
            echo "stress-ng fails to start!!!" | tee -a "$LOG"
            echo "0"
        fi
    fi
}

# Parameter: 1. CPU_LOAD(Optional. Without this parameter, It runs at full-load.)
# Return: PID of glmark2
gpu_burn()
{
    export DISPLAY=:0

    # Run glmark2 test
    # Get real full name of glmark2 on different platforms
    GL_MARK=$(compgen -c | grep glmark2)

    ( $GL_MARK --run-forever --fullscreen --annotate > /dev/null ) &
    if [ $? -eq 0 ]; then
        gpu_pid=$!
        if [ ! -z "$1" ]; then
            ( cpulimit --pid "$!" --limit "$1" > /dev/null ) &
        fi
        echo "$gpu_pid"
    else
        echo "$GL_MARK fails to start" | tee -a "$LOG"
        echo "0"
    fi
}

# Parameter: 1. CPU_LOAD(Optional. Without this parameter, It runs at full-load.)
# Return: PID of memtester
MEM_LOG=/memtester_test.log
mem_burn()
{
    if [ -f  $MEM_LOG ] ; then
        rm $MEM_LOG
    fi
    # Run DDR stress test
    memsize=$(free | grep Mem | awk -F ' ' '{print $4}')
    # Only use 70% of free memory
    memsize_byte=$(( memsize*700 ))
    #echo memsize ${memsize}
    #echo memsize_byte ${memsize_byte}
    echo 3 > /proc/sys/vm/drop_caches > /dev/null
    ( memtester ${memsize_byte}B > $MEM_LOG ) &
    if [ $? -eq 0 ]; then
        # Force to only use CPU 5% or it uses CPU 100% 
        mem_pid=$!
        if [ ! -z "$1" ]; then
            ( cpulimit --pid "$!" --limit "$1" > /dev/null ) &
        fi
        echo "$mem_pid"
    else
        echo "memtester fails to start" | tee -a "$LOG"
        echo "0"
    fi    
}
DEFAULT_IPER_SERVER='10.88.88.196'
wfi_config_server()
{
    ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del )  && ( sleep 1 )

    read -t 10 -p "Please set iperf server ip address (default: $DEFAULT_IPER_SERVER): " IPERF_IP
    echo
    if [ -z "$IPERF_IP" ]; then
        echo Skip to set iperf server ip.

        IPERF_IP="$DEFAULT_IPER_SERVER"
    fi
    echo Set IP address of iperf server as "${IPERF_IP}"

    sleep 5
}

# Return: location of LOG file
wifi_burn()
{
    ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del ) && ( sleep 1 )

    echo "iperf3 test is running..."

    iperf3 -c "$IPERF_IP" -t 10 -i 5 -w 3M -P 4 -l 24000 | tail -n 4 | tee -a "$1"
}

get_temperature()
{
    t=$(cat /sys/class/thermal/thermal_zone0/temp)
    temperature=$(( t/1000 ))
    echo $temperature
}

get_cpu_usage()
{
    cpu_usage=$(top -b -n2 -p 1 | \
    fgrep "Cpu(s)" | tail -1 | \
    awk -F'id,' -v prefix="$prefix" \
    '{ split($1, vs, ","); v=vs[length(vs)]; sub("%", "", v); printf "%s%.1f%%\n", prefix, 100 - v }')

    echo "$cpu_usage"
}

# Parameter: 1. PID
check_pid_exist()
{
    #echo 'inside check_pid_exist'
    if [ -z "$1" ]; then
        #echo 'empty PID'
        return 1
    elif (ps -p "$1" > /dev/null 2>&1 ); then
        #echo 'PID exist'
        return 0
    else
        #echo 'PID not exist'
        return 1
    fi
}
