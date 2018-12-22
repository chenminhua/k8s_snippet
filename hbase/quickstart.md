## quick start

wget https://www-eu.apache.org/dist/hbase/2.1.1/hbase-2.1.1-bin.tar.gz

bin/start-hbase.sh

bin/hbase shell

> status

> create 'testtable', 'colfaml'

> put 'testtable', 'myrow-1', 'colfaml:q1', 'value-1'
> put 'testtable', 'myrow-2', 'colfaml:q2', 'value-2'
> put 'testtable', 'myrow-2', 'colfaml:q3', 'value-3'

> list

> scan 'testtable'

> get 'testtable', 'myrow-1'

> delete 'testtable', 'myrow-2', 'colfaml:q2'

> disable 'testtable'

> drop 'testtable'

> exit

bin/stop-hbase.sh

## 安装条件

hbase 和 hadoop 通常安装在一起，此时一台机器上最少会有三个 java 进程（datanode, taskTracker, RegionServer）。

内存要大，数据节点的磁盘要大，四核以上的处理器。

典型的内存配置： NameNode 8G, SecondaryNameNode 8G, JobTracker 2G， Hbase Master 4G, DataNode 1G, Hbase RegionServer 12G。

#### 磁盘

#### 网络

#### 同步时间

集群中节点的时间必须一致，用户需要在集群中运行 NTP 来同步集群时间。

#### 文件描述符限制

要改大

#### datanode 处理线程数

conf/hdfs-site.xml 中的 dfs.datanode.max.xcievers 要改大，比如 4096

### 文件系统

本地模式，HDFS，S3，其他文件系统

## 运行模式

单击模式

分布式模式：伪分布式模式，完全分布式模式

#### 伪分布式模式

弄个 hdfs 配上就好了

#### 完全分布式模式

应该启动几台 zookeeper? 推荐使用 3，5，7 台；给每台 zookeeper 大约 1G 的内存和专用磁盘。如果负载非常高，zk 应该独立于 regionServer、DataNode 和 TaskTracker

## 数据的版本化

hbase 的一个特殊功能是，能为一个 cell 存储多个版本的数据。
