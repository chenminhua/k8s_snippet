#!/bin/bash
修改etc/hadoop/core-site.xml

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>


修改etc/hadoop/hdfs-site.xml

<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>

## 确保你可以ssh localhost
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

## 格式化文件系统
bin/hdfs namenode -format

## 启动namenode 和 datanode
sbin/start-dfs.sh
如果因为JAVA_HOME失败了的话,把export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk 写入 ./etc/hadoop/hadoop-env.sh

## 查看namenode
http://host:50070

## make hdfs 目录
bin/hdfs dfs -mkdir /user
bin/hdfs dfs -put /user/chenminhua

## 把文件拷贝进hdfs
bin/hdfs dfs -put etc/hadoop /user/chenminhua/input

## 执行
bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.9.2.jar grep /user/chenminhua/input /user/chenminhua/output 'dfs[a-z.]+'

## 取回结果并校验
bin/hdfs dfs -get /user/chenminhua/output output
cat output/*

## 停止dfs
sbin/stop-dfs.sh
