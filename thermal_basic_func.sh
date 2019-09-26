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


# Parameter: 1. CPU_LOAD
# Return: PID of stress-ng
cpu_burn()
{
    # Run CPU stress test with specific load
    ( stress-ng -c "$(nproc)" -l $1 > /dev/null ) &
    if [ $? -eq 0 ]; then
        echo "$!"
     else
        echo "stress-ng fails to start!!!" | tee -a $LOG
        echo "0"
    fi
   
}

# Return: PID of glmark2
gpu_burn()
{
    export DISPLAY=:0

    # Run glmark2 test
    # Get real full name of glmark2 on different platforms
    GL_MARK=$(compgen -c | grep glmark2)

    ( $GL_MARK --run-forever --fullscreen --annotate > /dev/null ) &
    if [ $? -eq 0 ]; then
        echo "$!"
    else
        echo "$GL_MARK fails to start" | tee -a $LOG
        echo "0"
    fi
}

mem_burn()
{
    # Run DDR stress test
    memsize=$(free | grep Mem | awk -F ' ' '{print $4}')
    # Only use 70% of free memory
    memsize_byte=$((${memsize}*700))
    #echo memsize ${memsize}
    #echo memsize_byte ${memsize_byte}
    echo 3 > /proc/sys/vm/drop_caches > /dev/null
    ( memtester ${memsize_byte}B 1 > /dev/null ) &
    if [ $? -eq 0 ]; then
        # Force to only use CPU 5% or it uses CPU 100% 
        mem_pid=$!
        ( cpulimit --pid $! --limit 5 > /dev/null ) &
        echo "$mem_pid"
    else
        echo "memtester fails to start" | tee -a $LOG
        echo "0"
    fi    
}

get_temperature()
{
    t=`cat /sys/class/thermal/thermal_zone0/temp`
    temperature=`expr $t / 1000`
    echo $temperature
}

get_cpu_usage()
{
    cpu_usage=`top -b -n2 -p 1 | \
    fgrep "Cpu(s)" | tail -1 | \
    awk -F'id,' -v prefix="$prefix" \
    '{ split($1, vs, ","); v=vs[length(vs)]; \
    sub("%", "", v); printf "%s%.1f%%\n", prefix, 100 - v }'`

    echo $cpu_usage
}

# Parameter: 1. PID
check_pid_exist()
{
    #echo 'inside check_pid_exist'
    if [ -z $1 ]; then
        #echo 'empty PID'
        return 1
    elif (ps -p $1 > /dev/null 2>&1 ); then
        #echo 'PID exist'
        return 0
    else
        #echo 'PID not exist'
        return 1
    fi
}
