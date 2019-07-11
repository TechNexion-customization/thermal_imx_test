#!/bin/sh

LOG=/thermal_gpu.log
if [ -f  $LOG ] ; then
    rm $LOG
fi

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
   
    dmesg -c | tail -f | grep 'System is too hot'
    if [ "$?" == "0" ]; then
        echo "===============================" | tee -a $LOG
        echo -n "Time to overheat: " && date -d@$diff_time -u +%H:%M:%S
        printf "Temperature: %d degree \n" $temperature | tee -a $LOG
        echo "===============================" | tee -a $LOG
        sync
        exit 0
    else
        echo "===============================" | tee -a $LOG
        printf "Running GPU burning test \n"
        echo -n "Elapsed time: " && date -d@$diff_time -u +%H:%M:%S
        printf "Temperature: %s degree \n" $temperature | tee -a $LOG
        echo "===============================" | tee -a $LOG
        sync
    fi
done
