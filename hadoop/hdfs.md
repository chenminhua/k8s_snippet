# hdfs

hadoop 有一个抽象的文件系统的概念，hdfs 只是其中的一个实现。其有好几个具体实现。LocalFileSystem, DistrubutedFileSystem, WebHdfsFileSystem...

分布式文件系统，架构于网络之上。使文件系统能够容忍节点故障且不丢失数据，就是一个极大的挑战。

### design

以流式数据访问模式来存储超大文件。流式数据访问：一次写入，多次读取是最高效的访问模式。

要求低时间延迟的数据访问应用不适合在 HDFS 上运行。HDFS 是为高数据吞吐量应用优化的，这会以提高时间延迟为代价。对于低延迟应用，hbase 是更好的选择。

大量小文件不适合使用 hdfs 存储。由于 namenode 将文件系统的元数据存储在内存中，因此文件系统可以存储的文件总数受限于 namenode 的内存容量。根据经验，每个文件、目录和数据块的存储信息大约占 150 字节。那么存一百万个文件且每个文件占一个数据块的话，至少需要 300MB 的内存。

HDFS 中的文件只支持单个写入者，而且写操作总是以只添加方式在文件末尾写数据。不支持多写入者操作，不支持任意位置修改。

### 块

文件系统块一般为几千字节，磁盘块一般为 512 字节。hdfs 同样也有块(block)的概念，但是大很多，默认为 128mb。但与面向单一磁盘的文件系统不同的是，hdfs 中小于块大小的文件不会占据整个块的空间。

为啥 hdfs 中的块这么大？ 目的是为了最小化寻址开销。

块抽象的好处在于，一个文件的大小可以大于网络中任意一个磁盘的容量。文件的所有块不需要存储在同一个磁盘上。简化了存储子系统的设计。同时文件的元数据不需要与文件的块一通存储。

tips: fsck 指令可以用于显示块信息。

### namenode 和 datanode

namenode: 管理节点。管理文件系统的命名空间。维护文件系统树以及整棵树内的文件和目录。命名空间镜像文件和编辑日志文件。namenode 也记录每个文件中各个块所在的数据节点信息。

datanode: 工作节点。根据需要存储并检索数据块，并定期向 namenode 发送它们存储的块的列表。

如果 namenode 损坏，文件系统上的所有文件都将会丢失，因为我们不知道如何根据 datanode 重建文件。因此对 namenode 实现容错非常重要。

#### namenode 容错

1. 备份。将持久状态写入本地磁盘的同时，写入一个远程挂载的 NFS。
2. 运行一个辅助的 namenode，定期合并编译日志与命名空间镜像。

#### 命令行

hadoop fs -mkdir /books
hadoop fs -ls /
hadoop fs -ls file:///
hadoop fs -ls hdfs:///

#### 接口

http

nfs 网关

#### java 接口

#### 远程访问

hdfs-site.xml

<property>
	<name>dfs.namenode.rpc-bind-host</name>
	<value>0.0.0.0</value>
</property>

## 数据流

客户端试图打开一个文件时，DistributedFileSystem 通过使用 RPC 来调用 namenode，以确定文件起始块的位置。对于每个块，namenode 返回存有该块副本的 datanode 地址。

DistributedFileSystem 返回一个 FSDataInputStream 对象给客户端来读取数据，该对象管理着 datanode 和 namenode 的 I/O。

接着，客户端对这个输入流调用 read()方法。存储着文件起始几个块的 datanode 地址的 DFSInputStream 随即连接距离最近的文件中第一个块所在的 datanode，并调用 read()读取数据，当读到块末端时，DFSInputStream 关闭与该 datanode 的连接，然后寻找下一个块的最佳 datanode。而对于客户来说，它只是在一直读取一个连续的流。

## 文件写入

客户端通过对 DistributedFileSystem 对象调用 create()来新建文件。DistributedFileSystem 对 namenode 发起 rpc 调用，在文件系统的命名空间中新建一个文件，此时文件中还没有相应数据块。如果成功，namenode 会为其创建一条记录，并返回一个 FSDataOutputStream 对象。此后，在客户端写入数据时，DFSOutputStream 将它分为一个个的数据包，并写入内部队列。同时 DFSOutputStream 也维护了一个内部数据包队列来等待 datanode 的确认回执。

在一个块被写入期间可能会有多个 datanode 同时发生故障，但非常少见。只要写入了 dfs.namenode.replication.min 的副本数（默认为 1），写操作就成功了。这个块可以在集群中异步复制，直到达到目标副本数（dfs.replication，默认为 3）。

客户端完成数据写入后，对数据流调用 close()方法。
