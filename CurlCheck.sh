#! /bin/bash

baseUrl=/home/TEST_LOGS/

dumpUrl=${baseUrl}DUMPS/

mkdir -p $baseUrl

mkdir -p $dumpUrl

#过滤进程的关键字
grepFilter="apache-tomcat-8.5.51-8081"
readonly grepFilter

#curl测试使用的命令
requestCurl=$(curl -I -m 5 -s -o /dev/null 127.0.0.1:8081 -w %{http_code})
readonly requestUrl

#测试正确的返回结果字符串
successStr="200"
readonly successStr

#允许最大失败次数
maxFault=3
readonly maxFault

#检测周期(秒)
checkPeriod=60
readonly checkPeriod
#注：stop app后sleep checkPeriod / 2
#注：start app后sleep checkPeriod * 5

#服务启动命令
startCmd="/home/apache-tomcat-8.5.51-8081/bin/startup.sh"
readonly startCmd

#服务关闭命令
stopCmd="/home/apache-tomcat-8.5.51-8081/bin/shutdown.sh"
readonly stopCmd

#格式化echo输出格式
fecho() {
    echo "$(date +"%Y-%m-%d %T") "$grepFilter" "$1
}

#格式化sleep执行过程
fsleep() {
    fecho "sleep "$1"s"
    sleep $1
}

funCheck() {

    fecho "Starting Test app ......"

    #$successStr加双引号避免$successStr为空的情况，会造成[比较报错
    if [ "$requestCurl" != "$successStr" ]; then

        cF=$(expr $cF + 1)

        fecho "Fault! Times "$cF

        #监测到app状态异常后，每5s重复检测，检测maxFault次判断app已经故障，需要重启
        fsleep 5

    else

        #只要监测成功就重置cF的值为0
        cF=0

        fecho "App test success"

        #每60s监测一次app的状态
        fsleep $checkPeriod
    fi

    #当前错误次数大于或者等于最大错误次数
    if [ $cF -ge $maxFault ]; then

        #重置cF
        cF=0

        fecho "Fault! Restart App..."

        javaPids=$(ps -ef | grep $grepFilter | grep -v grep | awk '{print $2}')

        fecho "App running pid="$javaPids

        #app故障时，生成dump文件，方便后面分析故障原因
        for loop in $javaPids; do

            fecho "Creating dump pid="$loop

            dumpFileName=$(date "+%Y-%m-%d-%H-%M-%S")
            dumpFile=$dumpUrl$dumpFileName.dump

            shell="jmap -dump:format=b,file=${dumpFile} ${loop}"

            $shell

            fecho "Zip dump file="$dumpFile

            zip -mq $dumpUrl$dumpFileName.zip $dumpFile

        done

        #记录当前内存使用情况
        fecho "Memory Status"
        free -m

        #记录网络情况
        fecho "Network Status"
        netstat -an | awk '/tcp/ {print $6}' | sort | uniq -c

        fecho "Running stop App:"$stopCmd
        $stopCmd

        fsleep $(expr $checkPeriod / 2)

        fecho "kill process="$javaPids
        kill -9 $javaPids

        fecho "Running start App:"$startCmd
        $startCmd

        #等待app启动起来，能够提供对外提供服务
        fsleep $(expr $checkPeriod \* 5)

    fi

}

while true; do

    #log日志YYYY-MM-DD.log
    logFileName=$baseUrl$(date +%Y-%m-%d).log

    #判断当天日期的log文件是否存在
    if test ! -e $logFileName; then

        #不存在就创建
        touch $logFileName

        #一周之前的日志文件
        lastWeekLogFile=$baseUrl$(date -d "-1 week" +%Y-%m-%d).log

        #存在
        if test -e $lastWeekLogFile; then

            #删除
            rm -rf $lastWeekLogFile

        fi
    fi

    #执行检测
    funCheck >>$logFileName
    #调试时，输出到窗口
    #funCheck

done
