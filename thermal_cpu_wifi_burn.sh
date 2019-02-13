#!/bin/sh


LOG=/temperature.log
if [ -f  $LOG ] ; then
    rm $LOG
fi


printf "\n\n\n ######## Start thermal test ######## \n\n\n"


sleep 5


( while [ 1 ]; do echo 100000000 | dhry | grep Dhrystones; done ) &
( while [ 1 ]; do echo 100000000 | dhry | grep Dhrystones; done ) &
( while [ 1 ]; do echo 100000000 | dhry | grep Dhrystones; done ) &
( while [ 1 ]; do echo 100000000 | dhry | grep Dhrystones; done ) &

start_time=$(date +%s)

while [ 1 ]
do
    sleep 3
    t=`cat /sys/class/thermal/thermal_zone0/temp`
    temperature=`expr $t / 1000`
    cpu_usage=`top -b -n2 -p 1 | \
fgrep "Cpu(s)" | tail -1 | \
awk -F'id,' -v prefix="$prefix" \
'{ split($1, vs, ","); v=vs[length(vs)]; \
sub("%", "", v); printf "%s%.1f%%\n", prefix, 100 - v }'`


    end_time=$(date +%s)


    diff_time=$(($end_time-$start_time))


    dmesg | tail -f | grep 'System is too hot'
    if [ "$?" == "0" ]; then
        echo "===============================" | tee -a $LOG
        echo -n "Time to overheat: " && date -d@$diff_time -u +%H:%M:%S
        printf "CPU usage: %s \n" $cpu_usage | tee -a $LOG
        printf "Temperature: %d degree \n" $temperature | tee -a $LOG
        echo "===============================" | tee -a $LOG
        sync
        exit 0
    else
        echo "===============================" | tee -a $LOG
        echo -n "Elapsed time: " && date -d@$diff_time -u +%H:%M:%S
        printf "CPU usage: %s \n" $cpu_usage | tee -a $LOG
        printf "Temperature: %s degree \n" $temperature | tee -a $LOG
        printf "Performing iperf3 test to 10.88.88.91... \n"
        iperf3 -c 10.88.88.91 -t 5 -i 5
        echo "===============================" | tee -a $LOG
        sync
    fi
done
