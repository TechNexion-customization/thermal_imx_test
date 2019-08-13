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

LOG=/thermal_gpu.log
if [ -f  $LOG ] ; then
    rm $LOG
fi


function gpu_set_max_temperature()
{
    echo
    read -t 10 -p "Please set the threshold temperature (default: 85 degree): " MAX_TEMP_STR
    echo

    if [ -z ${MAX_TEMP_STR} ]; then
        echo Skip to set threshold temerature.
        echo Set threshold temerature as 85 degree.
        MAX_TEMP_STR=85
    fi
}

function gpu_burn()
{
    #Get real full name of glmark2 on different platform
    GL_MARK=$(compgen -c | grep glmark2)

    $GL_MARK --run-forever --fullscreen --annotate &

    sleep 2

    PID=$$
    echo
    echo "PID is: $PID"

    while [ 1 ]
    do
        sleep 1

        t=`cat /sys/class/thermal/thermal_zone0/temp`
        temperature=`expr $t / 1000`

        echo

        MAX_TEMP=$((MAX_TEMP_STR))
        printf "Threshold temperature: %d degree \n" $MAX_TEMP

        ELAPSE_TIME=$(ps -p $PID -o etime | awk 'FNR == 2 {print $1}')

        if [ $temperature -ge $MAX_TEMP ]; then
            echo "===============================" | tee -a $LOG
            printf "Running GPU burning test \n" | tee -a $LOG
            printf "Time to overheat: %s \n" $ELAPSE_TIME | tee -a $LOG
            printf "Temperature: %d degree \n" $temperature | tee -a $LOG
            echo "===============================" | tee -a $LOG
            killall $GL_MARK
            sync
            exit 0
        else
            echo "===============================" | tee -a $LOG
            printf "Running GPU burning test \n" | tee -a $LOG
            printf "Elapsed time: %s \n" $ELAPSE_TIME | tee -a $LOG
            printf "Temperature: %s degree \n" $temperature | tee -a $LOG
            echo "===============================" | tee -a $LOG
            sync
        fi

        sleep 3
    done
}

function trap_ctrlc ()
{
    # perform cleanup here
    echo "Ctrl-C caught...performing clean up"

    echo "killall $GL_MARK"
    killall $GL_MARK
    echo
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trap "trap_ctrlc" 2

gpu_set_max_temperature

gpu_burn
