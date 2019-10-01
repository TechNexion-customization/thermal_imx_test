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

EXEC_PATH=$(dirname "$0")
FILE_NAME=$(basename -- "$0")
FILE_NAME="${FILE_NAME%.*}"
#echo "$EXEC_PATH"
#echo "$FILE_NAME"
source  "$EXEC_PATH"/thermal_basic_func.sh

LOG=/"$FILE_NAME".log
if [ -f  "$LOG" ] ; then
    rm "$LOG"
fi
echo LOG file is created under "$LOG"

cpu_mem_gpu_burn()
{
    PID_THIS=$$
    echo "PID is: $PID_THIS"
    wfi_config_server

    while true
    do
        sleep 1

        # Run CPU burning test with 50% load
        if ( ! check_pid_exist "$PID_CPU" ); then
	        PID_CPU=$(cpu_burn 50)
            echo ----start cpu_burn, PID "$PID_CPU"----
        fi

        # Run GPU burning test
        if ( ! check_pid_exist "$PID_GPU" ); then
	        PID_GPU=$(gpu_burn)
            echo ----start gpu_burn, PID "$PID_GPU"----
        fi

        # Run DDR burning test
        if ( ! check_pid_exist "$PID_MEM" ); then
	        PID_MEM=$(mem_burn)
            echo ----start mem_burn, PID "$PID_MEM"----
        fi
        failure_count=$(grep -c "FAILURE" "$MEM_LOG")


        cpu_usage=$(get_cpu_usage)
        temperature=$(get_temperature)
        echo 
     
        ELAPSE_TIME=$(ps -p "$PID_THIS" -o etime | awk 'FNR == 2 {print $1}')

        echo "===============================" | tee -a "$LOG"
        printf "Running CPU/Memory/GPU/WIFI burning test \n" | tee -a "$LOG"
        printf "Elapsed time: %s \n" "$ELAPSE_TIME" | tee -a "$LOG"
        printf "CPU usage: %s \n" "$cpu_usage" | tee -a "$LOG"
        printf "Temperature: %s degree \n" "$temperature" | tee -a "$LOG"
        printf "Memory test failure: %s \n" "$failure_count" | tee -a "$LOG"
        wifi_burn "$LOG"
        echo "===============================" | tee -a "$LOG"
        sync
        sleep 3
    done
}

trap_ctrlc ()
{
    # perform cleanup here
    echo "Ctrl-C caught...performing clean up"
    
    echo "killall stress-ng"
    echo
    killall stress-ng

    echo "killall $GL_MARK"
    echo
    killall "$GL_MARK"

    echo "killall memtester"
    echo
    killall memtester
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trap "trap_ctrlc" 2

cpu_mem_gpu_burn
