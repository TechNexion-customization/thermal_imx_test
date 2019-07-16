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

LOG=/thermal_vpu.log
if [ -f  $LOG ] ; then
    rm $LOG
fi

H264_FULLHD_LINK='http://samplemedia.linaro.org/H264/big_buck_bunny_1080p_H264_AAC_25fps_7200K.MP4'
WESTON_INI=/etc/xdg/weston/weston.ini
CONNMAN_CONF=/var/lib/connman/test.config
EXEC_PATH=$(dirname $(readlink -f "$0") )
GST_LAUNCH='gst-launch-1.0 playbin'
BG_PID=0

#only work under waylands
function vpu_rotate_display
{
    if [ $IS_WAYLAND = 'true' ]; then
        grep '^transform' $WESTON_INI
        if [ "$?" != "0" ]; then
            if [ $((RES_X)) -lt $((RES_Y)) ]; then
                cp $WESTON_INI $EXEC_PATH && sync
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

function connect_network
{
    if [ -s  $CONNMAN_CONF ]; then
        echo Checking network status...
        NETWORK_STATE=$(connmanctl state | grep State | tr -d ' ' | cut -d '=' -f 2)
        echo $NETWORK_STATE
        if [ $NETWORK_STATE = 'idle' ]; then
            echo Removing p2p interface and restarting connman.service...
            ( ifconfig -a | grep -q p2p ) && ( iw dev p2p0 del )
            systemctl restart connman.service
            loop=0
            while [ $loop -le 5 ]
            do
                 NETWORK_STATE=$(connmanctl state | grep State | tr -d ' ' | cut -d '=' -f 2)
                if [ $NETWORK_STATE == 'online' ]; then
                        return 0
                else
                        sleep 1
                fi
                loop=$(expr $loop + 1)
            done
        fi
    else
        ${EXEC_PATH}/configure_wifi.sh
    fi
}


function vpu_prepare_test_file
{
    
    if [ ! -s test.mp4 ]; then
        echo 'Can not find test.mp4. Start to download test media file...'
        connect_network
        wget $H264_FULLHD_LINK -O test.mp4
    else
        echo 'Find test.mp4!'
    fi
    TEST_FILE=$EXEC_PATH/test.mp4
}

function vpu_play()
{
    #Get real full name of glmark2 on different platform
    vpu_rotate_display && CHANGE_RES=true || CHANGE_RES=false

    while true; do
        sleep 1
        echo 3 > /proc/sys/vm/drop_caches
        sleep 1
        if [ $CHANGE_RES = 'true' ]; then
            echo x: $RES_X
            echo y: $RES_Y

            GST_WAYLAND="waylandsink window-width=$RES_Y window-height=$RES_X"
            echo $GST_WAYLAND
            $GST_LAUNCH uri=file:$TEST_FILE video-sink=''"$GST_WAYLAND"''
        else
            $GST_LAUNCH uri=file:$TEST_FILE
        fi
    done &

    BG_PID=$!; echo "$BG_PID"

    sleep 2
    start_time=$(date +%s)

    while [ 1 ]
    do
        sleep 1

        t=`cat /sys/class/thermal/thermal_zone0/temp`
        temperature=`expr $t / 1000`

        end_time=$(date +%s)

        diff_time=$(($end_time-$start_time))

        echo

        echo "===============================" | tee -a $LOG
        printf "Running VPU playback test \n"
        echo -n "Elapsed time: " && date -d@$diff_time -u +%H:%M:%S
        printf "Temperature: %s degree \n" $temperature | tee -a $LOG
        echo "===============================" | tee -a $LOG
        sync

        sleep 3
    done
}

function trap_ctrlc ()
{
    # perform cleanup here
    echo "Ctrl-C caught...performing clean up"

    echo "killall $GST_LAUNCH"
    killall $GST_LAUNCH
    kill $BG_PID
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    cp $EXEC_PATH/weston.ini $WESTON_INI && sync
    systemctl restart weston
    exit 2
}

trap "trap_ctrlc" 2

if [ -f $WESTON_INI ]; then
    IS_WAYLAND=true
    echo Running wayland...
    CONNECTOR=$( modetest -c | grep connected | awk '{print $(NF-3)}' )
    echo $CONNECTOR
    RES=$( modetest -p | grep -A3 CRTCs | awk 'END {print $(1)}' )
    if [ $RES == '0' ]; then
        echo There is no valid display
        return 0
    else
        echo $RES
        RES_X=$(echo $RES | cut -d 'x' -f 1)
        RES_Y=$(echo $RES | cut -d 'x' -f 2)
        echo Resolution:
        echo x: $RES_X
        echo y: $RES_Y
    fi
else
    ISWAYLAND=false
fi

vpu_prepare_test_file
vpu_play
