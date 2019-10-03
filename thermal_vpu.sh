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

H264_FULLHD_LINK='http://samplemedia.linaro.org/H264/big_buck_bunny_1080p_H264_AAC_25fps_7200K.MP4'
H264_FULLHD_MD5SUM="d68e46b777de4138ed05f3577b03a2c1"
WESTON_INI=/etc/xdg/weston/weston.ini
CONNMAN_CONF=/var/lib/connman/test.config
EXEC_PATH=$(dirname "$(readlink -f "$0")" )
GST_LAUNCH=$(compgen -c | grep gst-launch)
GST_LAUNCH_FULL=($GST_LAUNCH playbin)
BG_PID=0
TEST_FILE=$EXEC_PATH/test.mp4

#only work under waylands
vpu_rotate_display()
{
    if [ "$IS_WAYLAND" = 'true' ]; then
        grep '^transform' $WESTON_INI
        if [ "$?" != "0" ]; then
            if [ $((RES_X)) -lt $((RES_Y)) ]; then
                cp "$WESTON_INI" "$EXEC_PATH" && sync
                echo Rotating display 90 degree to landscape mode
cat << EOF >> $WESTON_INI

[output]
name=$CONNECTOR
transform=90
EOF
                sleep 1
                systemctl restart weston
                sleep 1
                return 0
            fi            
        else 
            echo The display is already rotated.
            return 0
        fi
    else
        echo Auto-rotation only works on Wayland. weston.ini does not exist.
        return 1
    fi
}

connect_network()
{
    echo Checking network status...
    NETWORK_STATE=$(connmanctl state | grep State | tr -d ' ' | cut -d '=' -f 2)

    if [ "$NETWORK_STATE" = 'online' ]; then
        echo network is connected!
        return 0
    fi

    if [ -s  $CONNMAN_CONF ]; then
        echo "$NETWORK_STATE"
        if [ "$NETWORK_STATE" = 'idle' ]; then
            echo Removing p2p interface and restarting connman.service...
            ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del ) && ( sleep 1 )
            systemctl restart connman.service
        fi
    else
        echo There is no connected network.
        read -t 30 -p "(1) Connect ethernet (2) Configure wifi:  " NET_TYPE
        echo
        case $NET_TYPE in
        1)
            udhcpc -i eth0
            ;;
        2)
            "${EXEC_PATH}"/configure_wifi.sh
            ;;
        *)
            echo "Wrong selection!!!"
            exit 0
            ;;
        esac

    fi

    loop=0
    while [ $loop -le 5 ]
    do
         NETWORK_STATE=$(connmanctl state | grep State | tr -d ' ' | cut -d '=' -f 2)
        if [ "$NETWORK_STATE" = 'online' ]; then
                return 0
        else
                sleep 1
        fi
        loop=$(( loop + 1 ))
    done
}


vpu_prepare_test_file()
{
    
    if [ ! -s "$TEST_FILE" ]; then
        echo 'Can not find test.mp4. Start to download test media file...'
        connect_network
        wget -c "$H264_FULLHD_LINK" -O "$TEST_FILE"
        MD5SUM=$(md5sum "$TEST_FILE" | awk '{print $(1)}')
        echo Checking MD5SUM: "$MD5SUM"
        loop=0
        while [ "$MD5SUM" != "$H264_FULLHD_MD5SUM" ] && [ $loop -le 3 ]
        do
            wget "$H264_FULLHD_LINK" -O "$TEST_FILE"
            MD5SUM=$(md5sum "$TEST_FILE")
            loop=$( loop + 1 )
        done
    else
        echo 'Find test.mp4!'
    fi
}

vpu_play()
{
    #Get real full name of glmark2 on different platform
    vpu_rotate_display && CHANGE_RES=true || CHANGE_RES=false

    while true; do
        sleep 1
        echo 3 > /proc/sys/vm/drop_caches
        sleep 1
        if [ $CHANGE_RES = 'true' ]; then
            echo x: "$RES_X"
            echo y: "$RES_Y"

            GST_WAYLAND="waylandsink window-width=$RES_Y window-height=$RES_X"
            echo "$GST_WAYLAND"
            "${GST_LAUNCH_FULL[@]}" uri=file:"$TEST_FILE" video-sink=''"$GST_WAYLAND"''
        else
            "${GST_LAUNCH_FULL[@]}" uri=file:"$TEST_FILE"
        fi
    done &

    BG_PID=$!; echo "$BG_PID"

    PID_THIS=$$
    echo "PID is: $PID_THIS"

    while true
    do
        sleep 1

        cpu_usage=$(get_cpu_usage)
        temperature=$(get_temperature)
        echo

        ELAPSE_TIME=$(ps -p "$PID_THIS" -o etime | awk 'FNR == 2 {print $1}')

        echo "===============================" | tee -a "$LOG"
        printf "Running VPU burning test \n" | tee -a "$LOG"
        printf "Elapsed time: %s \n" "$ELAPSE_TIME" | tee -a "$LOG"
        printf "CPU usage: %s \n" "$cpu_usage" | tee -a "$LOG"
        printf "Temperature: %s degree \n" "$temperature" | tee -a "$LOG"
        echo "===============================" | tee -a "$LOG"
        sync
        sleep 3
    done
}

function trap_ctrlc ()
{
    # perform cleanup here
    echo "Ctrl-C caught...performing clean up"

    echo "killall $GST_LAUNCH"
    killall "$GST_LAUNCH"
    kill "$BG_PID"
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    cp "$EXEC_PATH"/weston.ini "$WESTON_INI" && sync
    systemctl restart weston
    echo
    exit 2
}

trap "trap_ctrlc" 2

if [ -f $WESTON_INI ]; then
    IS_WAYLAND=true
    echo Running wayland...
    CONNECTOR=$( modetest -c | grep connected | awk '{print $(NF-3)}' )
    echo "$CONNECTOR"
    RES=$( modetest -p | grep -A3 CRTCs | awk 'END {print $(1)}' )
    if [ "$RES" = '0' ]; then
        echo There is no valid display
        return 0
    else
        echo "$RES"
        RES_X=$(echo "$RES" | cut -d 'x' -f 1)
        RES_Y=$(echo "$RES" | cut -d 'x' -f 2)
        echo Resolution:
        echo x: "$RES_X"
        echo y: "$RES_Y"
    fi
else
    IS_WAYLAND=false
fi

vpu_prepare_test_file
vpu_play

