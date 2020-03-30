#! /bin/bash

a='{"result_code":"-1","result_msg":"服务不存在！"}'

readonly a

logFilePath=/home/TEST_LOGS/

dumpUrl=/home/TEST_LOGS/DUMPS/

mkdir -p $logFilePath

mkdir -p $dumpUrl

while true; do

    logFileName=$logFilePath$(date +%Y-%m-%d).log

    lastWeekLogFile=$logFilePath$(date -d "-1 week" +%Y-%m-%d).log

    if test ! -e $logFileName; then

        touch $logFileName

        if test -e $lastWeekLogFile; then

            rm -rf $lastWeekLogFile

        fi
    fi

    echo Starting Test tomcat >>$logFileName

    b=$(curl -m 5 -s 127.0.0.1:8888/api/services/1)

    if [ "$a" != "$b" ]; then

        tC=$(expr $tC + 1)

        echo "Fault! Count "$tC >>$logFileName

        #监测到tomcat状态异常后，每5s重复检测，检测10次判断tomcat已经故障，需要重启
        sleep 5

    else

        #只要监测成功就重置tC的值为0
        tC=0

        echo "$(date +"%Y-%m-%d %T") tomcat test success" >>$logFileName

        #每60s监测一次tomcat的状态
        sleep 60
    fi

    if [ $tC -ge 10 ]; then

        tC=0

        echo "Fault! Restart App..." >>$logFileName

        javaPids=$(ps -ef | grep tomcat | grep -v grep | awk '{print $2}')

        echo "tomcat pid="$javaPids >>$logFileName

        #tomcat故障时，生成dump文件，方便后面分析故障原因
        for loop in $javaPids; do

            dumpFileName=$(date "+%Y-%m-%d-%H-%M-%S")
            dumpFile=$dumpUrl$dumpFileName.dump

            shell="jmap -dump:format=b,file=${dumpFile} ${loop}"

            $shell >>$logFileName

            zip -mq $dumpUrl$dumpFileName.zip $dumpFile

        done

        #记录当前内存使用情况
        free -m >>$logFileName

        #记录网络情况
        netstat -ant | awk '/^tcp/ {++S[$NF]} END {for(a in S) print (a,S[a])}' >>$logFileName

        /home/apache-tomcat-8.5.51-8081/bin/shutdown.sh

        kill -9 $javaPids >>$logFileName

        /home/apache-tomcat-8.5.51-8081/bin/startup.sh

        #等待tomcat启动起来，能够提供对外提供服务
        sleep 60

    fi

done
