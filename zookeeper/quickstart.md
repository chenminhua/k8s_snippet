wget http://mirror.bit.edu.cn/apache/zookeeper/zookeeper-3.4.10/zookeeper-3.4.10.tar.gz

### standalone

```sh
## vi conf/zoo.cfg
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
```

tickTime: 心跳间隔，此次为 2s 一个心跳。zk 里最小超时时间为这个时间的两倍。

dataDir: the location to store the in-memory database snapshots and, unless specified otherwise, the transaction log of updates to the database.

启动
bin/zkServer.sh start

客户端连接
bin/zkCli.sh -server 127.0.0.1:2181

> help
> ls /

> create /zk_test mydata
> ls /

> get /zk_test

> set /zk_test junk
> get /zk_test

> delete /zk_test

### 生产环境

```
tickTime=2000
dataDir=/var/lib/zookeeper
clientPort=2181
initLimit=5
syncLimit=2
server.1=zoo1:2888:3888
server.2=zoo2:2888:3888
server.3=zoo3:2888:3888
```

initLimit 集群中的 follower 服务器(F)与 leader 服务器(L)之间 初始连接 时能容忍的最多心跳数（tickTime 的数量）。默认为 10。
syncLimit 集群中的 follower 服务器(F)与 leader 服务器(L)之间 请求和应答 之间能容忍的最多心跳数（tickTime 的数量）。
