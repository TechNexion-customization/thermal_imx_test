#!/bin/sh

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
    start_time=$(date +%s)

    while [ 1 ]
    do
        sleep 1

        t=`cat /sys/class/thermal/thermal_zone0/temp`
        temperature=`expr $t / 1000`

        end_time=$(date +%s)

        diff_time=$(($end_time-$start_time))

        echo

        MAX_TEMP=$((MAX_TEMP_STR))
        printf "Threshold temperature: %d degree \n" $MAX_TEMP

        if [ $temperature -ge $MAX_TEMP ]; then
            echo "===============================" | tee -a $LOG
            echo -n "Time to overheat: " && date -d@$diff_time -u +%H:%M:%S
            printf "Temperature: %d degree \n" $temperature | tee -a $LOG
            echo "===============================" | tee -a $LOG
            killall $GL_MARK
            sync
            exit 0
        else
            echo "===============================" | tee -a $LOG
            printf "Running CPU burning test \n"
            echo -n "Elapsed time: " && date -d@$diff_time -u +%H:%M:%S
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
    # exit shell script with error code 2
    # if omitted, shell script will continue execution
    exit 2
}

trap "trap_ctrlc" 2

gpu_set_max_temperature

gpu_burn
