#!/bin/bash
修改 etc/hadoop/mapred-site.xml

<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>


修改 etc/hadoop/yarn-site.xml

<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>


## 启动 ResourceManager 和 NodeManager
sbin/start-yarn.sh

## 访问
http://host:8088

## 停止
sbin/stop-yarn.sh
