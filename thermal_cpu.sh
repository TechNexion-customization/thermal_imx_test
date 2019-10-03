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
source "$EXEC_PATH"/thermal_basic_func.sh

LOG=/"$FILE_NAME".log
if [ -f  "$LOG" ]; then
    rm "$LOG"
fi
echo LOG file is created under "$LOG"

thermal_cpu()
{
    PID_THIS=$$
    echo "PID is: $PID_THIS"
    
    while true
    do
        sleep 1

        # Run CPU burning test with full-load
        if ( ! check_pid_exist "$PID_CPU" ); then
	        PID_CPU=$(cpu_burn)
            echo ----start cpu_burn, PID "$PID_CPU"----
        fi

        cpu_usage=$(get_cpu_usage)
        temperature=$(get_temperature)
        echo

        ELAPSE_TIME=$(ps -p "$PID_THIS" -o etime | awk 'FNR == 2 {print $1}')

        echo "===============================" | tee -a "$LOG"
        printf "Running CPU burning test \n" | tee -a "$LOG"
        printf "Elapsed time: %s \n" "$ELAPSE_TIME" | tee -a "$LOG"
        printf "CPU usage: %s \n" "$cpu_usage" | tee -a "$LOG"
        printf "Temperature: %s degree \n" "$temperature" | tee -a "$LOG"
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
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trap "trap_ctrlc" 2

thermal_cpu
