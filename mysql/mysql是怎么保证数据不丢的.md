## binlog 写入机制

事务执行过程中，先把日志写到 binlog cache，事务提交时再把 binlog cache 写入 binlog 文件中。

系统给 binlog cache 分配了一片内存，每个线程一个，参数 binlog_cache_size 用于控制单个线程内 binlog cache 所占内存的大小。如果超过这个参数规定大小，就要暂存到磁盘。

事务提交时，binlog cache 中的完整事务写入 binlog，并清空 binlog cache。事实上，binlog cache 写入到 binlog 文件的步骤也是分两步的。第一步是写入文件系统的 page cache，第二步才是 fsync 到磁盘。

sync_binlog=0 的时候，表示每次提交事务都只 write,不 fsync.

sync_binlog=1 的时候，表示每次提交事务都会执行 fsync.

sync_binlog=N(N>1) 的时候，表示每次提交事务都 write，但累积 N 个事务后才 fsync。

如果你的 io 是瓶颈，可以考虑将 sync_binlog 设大一点，但是就会存在异常重启时丢失事务 binlog 的风险。一般不建议将 sync_binlog 设置为 0，会丢日志。
