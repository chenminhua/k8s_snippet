buff 是内核缓冲区用到的内存，对应的是/proc/meminfo 中的 buffers 值。

cache 是内核页缓存和 slab 用到的内存，对应的是/proc/meminfo 中的 cached 与 SReclaimable 之和。

## proc 文件系统

/proc 是 Linux 内核提供的一种特殊文件系统，是用户与内核交互的接口。用户可以从/proc 查询内核运行状态与配置选项，进程的运行状态等

man proc 可以查看 proc 文件系统的详细文档。

buffers 是对原始磁盘块的临时存储，也就是用来缓存磁盘的数据，不会特别大。

cached 是从磁盘读取文件的页缓存，也就是用来缓存文件读取的数据。

SReclaimable 是 slab 的一部分（可回收的那部分）。

## 写文件案例

```
# 清理文件页、目录项、Inodes 等各种缓存
echo 3 > /proc/sys/vm/drop_caches

vmstat 1
# bi和bo分别表示块设备读取和写入的大小，单位为块/秒，等价于kb/s

# 通过读取随机设备，生成一个500MB大小的文件
dd if=/dev/urandom of=/tmp/file bs=1M count=500
```

我们发现 cache 在不断变大，而 buffer 基本不变。

## 写磁盘案例

```
echo 3 > /proc/sys/vm/drop_caches
vmstat 1

# 这次我们向磁盘分区写入2g数据
dd if=/dev/urandom of=/dev/sdb1 bs=1M count=2048
```

这时我们看到 cache 基本没有变化，但是 buffer 却一直在涨

## 读文件和读磁盘

```
# 首先清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
# 运行 dd 命令读取文件数据
$ dd if=/tmp/file of=/dev/null
```

读文件，bi 和 cache 在涨

```
# 首先清理缓存
$ echo 3 > /proc/sys/vm/drop_caches
# 运行 dd 命令读取文件
$ dd if=/dev/sda1 of=/dev/null bs=1M count=1024
```

读磁盘，bi 和 buff 在涨。

## 总结

Buffer 是对磁盘数据的缓存，而 Cache 是文件数据的缓存，它们既会用在读请求中，也会用在写请求中。

## 缓存命中率

直接通过缓存获取数据的请求次数占所有数据请求次数的百分比。命中率越高，表示使用缓存带来的收益越高，应用程序的性能也就越好。

cachestat 和 cachetop，他们都是 bcc 软件包的一部分，基于内核的 eBPF 机制，来跟踪内核中管理的缓存，并输出缓存的使用和命中情况。

yum install bcc-tools

并把 /usr/share/bcc/tools 加入 path

## 查看文件的缓存大小

go get github.com/tobert/pcstat

pcstat filepath

# 内存回收

内核有一个专门的线程来回收内存，也就是 kswapd0，为了衡量内存使用情况，kswapd0 定义了三个内存阈值(页最小阈值 pages_min，页低阈值 pages_low，页高阈值 pages_high)，一旦剩余内存低于 pages_low，就会触发内存回收
