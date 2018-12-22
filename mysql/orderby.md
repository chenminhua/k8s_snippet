排序可能在内存中完成，也可能需要使用外部排序，这取决于排序所需的内存和参数 sort_buffer_size。
如果排序需要的数据量小于 sort_buffer_size，排序就在内存中完成，但是如果排序数据量太久，内存放不下，就利用磁盘临时文件辅助排序。

```
/* 打开 optimizer_trace，只对本线程有效 */
SET optimizer_trace='enabled=on';

/* @a 保存 Innodb_rows_read 的初始值 */
select VARIABLE_VALUE into @a from  performance_schema.session_status where variable_name = 'Innodb_rows_read';

/* 执行语句 */
select city, name,age from t where city='杭州' order by name limit 1000;

/* 查看 OPTIMIZER_TRACE 输出 */
SELECT * FROM `information_schema`.`OPTIMIZER_TRACE`\G

/* @b 保存 Innodb_rows_read 的当前值 */
select VARIABLE_VALUE into @b from performance_schema.session_status where variable_name = 'Innodb_rows_read';

/* 计算 Innodb_rows_read 差值 */
select @b-@a;
```

可以从 number_of_tmp_files 中看到是否使用了临时文件，其表示排序过程中使用的临时文件数。

## rowid 排序

如果 Mysql 担心排序内存太小，会影响排序效率，才会采用 rowid 算法，这样排序过程中一次可以排序更多行，但是需要回表取数据。
