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

LOG=/thermal_wifi.log
if [ -f  $LOG ] ; then
    rm $LOG
fi

function wfi_config_server()
{
    ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del )  && ( sleep 1 )

    read -t 10 -p "Please set iperf server ip address (default: 10.88.88.88): " IPERF_IP
    echo 
    if [ -z ${IPERF_IP} ]; then
        echo Skip to set iperf server ip.
        
        IPERF_IP='10.88.88.88'
        echo Set default ip address as ${IPERF_IP}
    fi
}

function wfi_burn()
{
    ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del ) && ( sleep 1 )

    sleep 5

    PID=$$
    echo "PID is: $PID"

    while [ 1 ]
    do
        sleep 3
        t=`cat /sys/class/thermal/thermal_zone0/temp`
        temperature=`expr $t / 1000`

        echo
        ELAPSE_TIME=$(ps -p $PID -o etime | awk 'FNR == 2 {print $1}')

        echo "===============================" | tee -a $LOG
        printf "Running WIFI burning test \n" | tee -a $LOG
        printf "Elapsed time: %s \n" $ELAPSE_TIME | tee -a $LOG
        printf "CPU temperature: %s degree \n" $temperature | tee -a $LOG
        printf "Performing iperf3 test to %s ...\n" ${IPERF_IP} | tee -a $LOG
        iperf3 -c ${IPERF_IP} -t 10 -i 5 -w 3M -P 4 -l 24000 
        echo "===============================" | tee -a $LOG
        sync

    done
}

function trap_ctrlc ()
{
    # perform cleanup here
    echo "Ctrl-C caught...performing clean up"
    
    echo "killall iperf3"
    killall iperf3
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trap "trap_ctrlc" 2

wfi_config_server
wfi_burn