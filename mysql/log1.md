## redo log

默认在事务提交时，将 redo log 缓冲写入 redo log 文件，并调用 fsync 操作。
参数 innodb_flush_log_at_trx_commit 用来控制是否每次都在提交时写入文件。

WAL，先写日志并更新内存，再写磁盘。将随机写变为顺序写。

InnoDB 的 redo log 是固定大小的，比如可以配置为一组 4 个文件，每个文件的大小是 1GB，那么总共就可以记录 4GB 的操作。redo log 给 Mysql 提供了 crash-safe 的能力。

redolog 有两个位置，一个是 write pos，另一个是 checkpoint。write pos 一边写一边往后移动，checkpoint 则是当 redolog 中的内容 flush 到磁盘后往后移动。当 write pos 追上 checkpoint 时，redolog 就写满了，这时候不能再执行写操作，要先停下来将 checkpoint 往后移动，也就是 flush 一些脏页到磁盘。

对一个简单的 update 操作，执行器会先写内存，然后写 redo log 并记为 prepare 阶段，再写 binlog，然后将 redo log 标记为 commit。注意，redo log 的写入拆成了两个步骤：prepare 和 commit，这就是**两阶段提交**。

如果你需要将数据库恢复到指定的某一秒，首先，找到最近的一次全量备份，如果你运气好，可能就是昨天晚上的一个备份，从这个备份恢复到临时库；然后，从备份的时间点开始，将备份的 binlog 依次取出来，重放到中午误删表之前的那个时刻。这样你的临时库就跟误删之前的线上库一样了，然后你可以把表数据从临时库取出来，按需要恢复到线上库去。

如果没有两阶段提交，就可能出现丢失 binlog 或多出 binlog 的问题，数据库的状态就有可能和用它的日志恢复出来的库的状态不一致。当你需要扩容的时候，也就是需要再多搭建一些备库来增加系统的读能力的时候，现在常见的做法也是用全量备份加上应用 binlog 来实现的。

redo log 用于保证 crash-safe 能力。innodb_flush_log_at_trx_commit 这个参数设置成 1 的时候，表示每次事务的 redo log 都直接持久化到磁盘。这个参数我建议你设置成 1，这样可以保证 MySQL 异常重启之后数据不丢失。

更新数据时，先写 redo log 和更新内存，之后再找时间更新磁盘数据页。**当内存数据页跟磁盘数据页内容不一致的时候，我们称这个内存页为“脏页”。内存数据写入到磁盘后，内存和磁盘上的数据页的内容就一致了，称为“干净页”**。平时执行很快的更新操作，其实就是在写内存和日志，而 MySQL 偶尔“抖”一下的那个瞬间，可能就是在刷脏页（flush）。

## 什么情况会引发数据库的 flush 过程呢？

1. redo log 写不下了。这时候系统会停止所有更新操作进行 flush。这种情况是 InnoDB 要尽量避免的。
2. 系统内存不足，需要淘汰一些数据页，空出内存给别的数据页使用。如果淘汰的是“脏页”，就要先将脏页写到磁盘。
3. 系统空闲的时候。
4. MySQL 正常关闭的情况。

内存不够用了，要先将脏页写到磁盘，这种情况其实是常态。InnoDB 的策略是尽量使用内存，因此对于一个长时间运行的库来说，未被使用的页面很少。而当要读入的数据页没有在内存的时候，就必须到缓冲池中申请一个数据页。这时候只能把最久不使用的数据页从内存中淘汰掉：如果要淘汰的是一个干净页，就直接释放出来复用；但如果是脏页呢，就必须将脏页先刷到磁盘，变成干净页后才能复用。

所以，刷脏页虽然是常态，但是出现以下这两种情况，都是会明显影响性能的：

1.  一个查询要淘汰的脏页个数太多，会导致查询的响应时间明显变长；

2.  日志写满，更新全部堵住，写性能跌为 0，这种情况对敏感业务来说，是不能接受的。

所以，InnoDB 需要有控制脏页比例的机制，来尽量避免上面的这两种情况。

## InnoDB 刷脏页的控制策略

这就要用到 innodb_io_capacity (我的机器设的是 4000)这个参数了，它会告诉 InnoDB 你的磁盘能力。这个值我建议你设置成磁盘的 IOPS。磁盘的 IOPS 可以通过 fio 这个工具来测试，下面的语句是我用来测试磁盘随机读写的命令：

     fio -filename=$filename -direct=1 -iodepth 1 -thread -rw=randrw -ioengine=psync -bs=16k -size=500M -numjobs=10 -runtime=10 -group_reporting -name=mytest

如果你的主机磁盘用的是 SSD，但是却设置了很低的 innodb_io_capacity，InnoDB 认为你的机器很烂，所以刷脏页刷得很慢，这样就造成了脏页累积，影响了查询和更新性能。

虽然我们现在已经定义了“全力刷脏页”的行为，但平时总不能一直是全力刷吧？毕竟磁盘能力不能只用来刷脏页，还需要服务用户请求。所以接下来，我们就一起看看 InnoDB 怎么控制引擎按照“全力”的百分比来刷脏页。

InnoDB 的刷盘速度就是要参考这两个因素：一个是脏页比例，一个是 redo log 写盘速度。参数 innodb_max_dirty_pages_pct 是脏页比例上限，默认值是 75%。

现在你知道了，InnoDB 会在后台刷脏页，而刷脏页的过程是要将内存页写入磁盘。所以，无论是你的查询语句在需要内存的时候可能要求淘汰一个脏页，还是由于刷脏页的逻辑会占用 IO 资源并可能影响到了你的更新语句，都可能是造成你从业务端感知到 MySQL“抖”了一下的原因。

要尽量避免这种情况，你就要合理地设置 innodb_io_capacity 的值，并且**平时要多关注脏页比例，不要让它经常接近 75%**。

**脏页比例是通过 Innodb_buffer_pool_pages_dirty/Innodb_buffer_pool_pages_total 得到的**

一旦一个查询请求需要在执行过程中先 flush 掉一个脏页时，这个查询就可能要比平时慢了。而 MySQL 中的一个机制，可能让你的查询会更慢：在准备刷一个脏页的时候，如果这个数据页旁边的数据页刚好是脏页，就会把这个“邻居”也带着一起刷掉；而且这个把“邻居”拖下水的逻辑还可以继续蔓延，也就是对于每个邻居数据页，如果跟它相邻的数据页也还是脏页的话，也会被放到一起刷。在 InnoDB 中，innodb_flush_neighbors 参数就是用来控制这个行为的，值为 1 的时候会有上述的“连坐”机制，值为 0 时表示不找邻居，自己刷自己的。

找“邻居”这个优化在机械硬盘时代是很有意义的，可以减少很多随机 IO。机械硬盘的随机 IOPS 一般只有几百，相同的逻辑操作减少随机 IO 就意味着系统性能的大幅度提升。而如果使用的是 SSD 这类 IOPS 比较高的设备的话，我就建议你把 innodb_flush_neighbors 的值设置成 0。因为这时候 IOPS 往往不是瓶颈，而“只刷自己”，就能更快地执行完必要的刷脏页操作，减少 SQL 语句响应时间。在 MySQL 8.0 中，innodb_flush_neighbors 参数的默认值已经是 0 了。

## binlog

sync_binlog 这个参数设置成 1 的时候，表示每次事务的 binlog 都持久化到磁盘。这个参数我也建议你设置成 1，这样可以保证 MySQL 异常重启之后 binlog 不丢失。

1.  redo log 是 InnoDB 引擎特有的；binlog 是 MySQL 的 Server 层实现的，所有引擎都可以使用。
2.  redo log 是物理日志，记录的是“在某个数据页上做了什么修改”；binlog 是逻辑日志，记录的是这个语句的原始逻辑，比如“给 ID=2 这一行的 c 字段加 1 ”。
3.  redo log 是循环写的，空间固定会用完；binlog 是可以追加写入的。“追加写”是指 binlog 文件写到一定大小后会切换到下一个，并不会覆盖以前的日志。

mysql-bin.index 文件是所有 bin log 文件的列表

查看所有 binlog
show binary logs;

查看某一个 binlog 中的 events
show binlog events in 'mysql-bin.000001';

关闭当前使用的 binary log，然后打开一个新的 binary log 文件
flush logs;

查看是否打开 binlog
show variables like 'log_bin';

查看当前数据库 binlog 的位置
show master status;

获取指定位置的 binlog
show binlog events from 123;

a、提取指定的 binlog 日志
mysqlbinlog /opt/data/APP01bin.000001
mysqlbinlog /opt/data/APP01bin.000001|grep insert

/_!40019 SET @@session.max_insert_delayed_threads=0_/;
insert into tb values(2,'jack')

b、提取指定 position 位置的 binlog 日志
mysqlbinlog --start-position="120" --stop-position="332" /opt/data/APP01bin.000001

c、提取指定 position 位置的 binlog 日志并输出到压缩文件
mysqlbinlog --start-position="120" --stop-position="332" /opt/data/APP01bin.000001 |gzip >extra_01.sql.gz

d、提取指定 position 位置的 binlog 日志导入数据库
mysqlbinlog --start-position="120" --stop-position="332" /opt/data/APP01bin.000001 | mysql -uroot -p

e、提取指定开始时间的 binlog 并输出到日志文件
mysqlbinlog --start-datetime="2014-12-15 20:15:23" /opt/data/APP01bin.000002 --result-file=extra02.sql

f、提取指定位置的多个 binlog 日志文件
mysqlbinlog --start-position="120" --stop-position="332" /opt/data/APP01bin.000001 /opt/data/APP01bin.000002|more

g、提取指定数据库 binlog 并转换字符集到 UTF8
mysqlbinlog --database=test --set-charset=utf8 /opt/data/APP01bin.000001 /opt/data/APP01bin.000002 >test.sql

h、远程提取日志，指定结束时间
mysqlbinlog -urobin -p -h192.168.1.116 -P3306 --stop-datetime="2014-12-15 20:30:23" --read-from-remote-server mysql-bin.000033 |more

i、远程提取使用 row 格式的 binlog 日志并输出到本地文件
mysqlbinlog -urobin -p -P3606 -h192.168.1.177 --read-from-remote-server -vv inst3606bin.000005 >row.sql

## undo log

undo log 保证了事务的一致。
undo log 存放数据修改前的值。
undo log 随机写，帮助事务的回滚以及 mvcc 的功能。
