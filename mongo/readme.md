# 简介

c++编写，文档型，无 schema, B-tree，自动分片，支持复制，bson 二进制格式存储，tab 补全，TCP 套接字
默认使用 fire-and-forget 模式（可以开启安全模式）
即时查询，不支持 join 操作

读写比率？需要何种查询？如何更新数据（事务）？有什么样的并发问题？数据结构化程度？
schema 设计原则？？？

可用还是一致？？
事务？？？

# mmap

数据文件通过 mmap()系统调用被映射成了系统的虚拟内存，这一举措将内存管理的重任交给了操作系统内核。

# 索引

mongoDB 中的二级索引是用 B-tree 实现的，每个集合最多可以创建 64 个索引。升降序，唯一索引，复合键索引，地理空间索引都被支持。

# 复制

mongo 通过副本集(replica set)的拓扑结构提供了复制功能。
主从结构，主节点可读可写，从节点只能读。
auto fail over，自动选出主节点

# 速度与持久性

速度与持久性存在一种相反的关系！！
mongo 中可以开启 journaling 日志，记录所有操作（类似 binlog）。
对于低价值高容量的数据，可以 fire-and-forget，而重要数据则开启安全模式。

# 水平扩展（自动分片）

# 命令工具

mongodump, mongorestore 备份/恢复数据
mongoexport, mongoimport 导入导出 json,csv 数据
mongosniff 网络嗅探，观察发送数据
mongostat 类似于 iostat，查看 Mongo 状态
bsondump
mongofiles

# use case

web 应用程序，日志，实时分析
无 schema 让你在前期可以更敏捷地进行开发
目标原子更新与固定集合(capped collection)？？？？？？

# 局限

mongodb 通常应当运行在 64 位机器上，32 位系统只能对 4G 内存进行寻址。
Mongodb 使用 mmap(),很吃内存，最好单独部署。
如果没有开启复制功能，并且没有开启 journaling 日志，则很容易导致数据损坏。

# mongodb

use school
db 查看当前数据库  
show dbs
db.dropDatabase()
db.person.insert({"id":1,"name":"cmh"})
show collections
db.person.count()
db.person.drop()
db.person.find({},{"name":1}) //显示\_id 和 name
db.person.find({},{"name":0}) //只不显示 name
db.person.find({},{"\_id":0,"id":0}) //只不显示\_id 和 id
db.person.find().limit(2) 只返回前两个结果
db.person.find().limit(1).skip(1) 只返回跳过一个后的第一个结果（第二个结果）
db.person.find().sort({"id":1}) 按照 id 升序排列
db.person.find().sort({"id":-1}) 按照 id 降序排列

db.person.remove()
db.person.remove({"id":1})
db.person.remove({"name":"wushaohan"},1) 只删除符合条件的多条记录中的第一条

统计信息
db.stats()
db.person.stats()

把之前定义的一个文档名叫 cmh，改为 chenminhua，并将其设为管理员
db.person.update({"name":"cmh"},{$set {"name":"chenminhua"}})
mongodb默认只更新单一文档，如果要多更新（比如你有好几个person都叫cmh，全都需要更新），就要设置{multi: true}
db.person.update({"name":"cmh"},{$set {"name":"chenminhua"}},{multi:true})

##数据类型
String, Integer, Boolean, Double, Arrays, Timestamp, Date, Object, Null, Object ID
Min/ Max keys : 这种类型被用来对 BSON 元素的最低和最高值比较。
Symbol : 此数据类型用于字符串相同，但它通常是保留给特定符号类型的语言使用。
Binary data : 此数据类型用于存储二进制数据。
Regular expression : 此数据类型用于存储正则表达式

##索引
如果没有索引，MongoDB 必须扫描每一个文档的集合，要选择那些文档相匹配的查询语句。这种扫描的效率非常低，要做大数据量的处理。
索引是一种特殊的数据结构，存储设置在一个易于遍历形式的数据的一小部分。索引存储一个特定的字段或一组字段的值，在索引中指定的值的字段排列的。
for (i=0; i<200000; i++) {db.numbers.save({num: i})}
db.numbers.find({num:{"$gt": 19995}})
db.numbers.find({num:{"$gt": 19995}}).explain()
db.numbers.ensureIndex({"num":1}) 对 person 这个 collection 在 id 上创建升序索引
db.numbers.getIndexes()

##聚合(相当于 group by)

```
aggregate
```

##基本查询
看其中一个 document

```
db.test.findOne()
```

看一看有哪些 document

```
db.test.find()
```

条件查询

```
db.test.find({"name":"stephen", "age":35})
```

查询条件

```
$lt $lte $gt $gte $ne 依次等价于< <= > >= !=
db.test.find({"age":{"$gte":18, "$lte":40}})
db.test.find({"name":{"$ne": "stephen1"}})

$in 等同于sql中的in， 但是和sql不同的是list中的数据可以属于不同类型
db.test.find({"name":{"$in":["stephen","stephen1"]}})

$nin 等同于sql中的not in,同时也是$in的取反
db.test.find({"name":{"$nin":["stephen2","stephen1"]}})

$or
db.test.find({"$for":[{"name":"stephen1"},{"age":35}]})

$not
db.test.find({"name":{"not":{"$in":["stephen2","stephen1"]}}})

null数据查询
在进行值为null数据的查询时，所有值为null，以及不包含指定键的文档均会被检索出来。
db.test.find({"x":null})

需要将null作为数组中的一个元素进行相等性判断，即便这个数组中只有一个元素。
再有就是通过$exists判断指定键是否存在。
db.test.find({"x": {"$in": [null], "$exists":true}})

正则查询（使用了perl规则的正则语法）
db.test.find({"name":/stephen?/i})      //i表示忽略大小写
```

数组数据查询

```
数组中所有包含banana的文档都会被检索出来。
db.test.find({"fruit":"banana"})
检索数组中需要包含多个元素的情况，这里使用$all。下面的示例中，数组中必须同时包含apple和banana，但是他们的顺序无关紧要。
db.test.find({"fruit": {"$all": ["banana","apple"]}})
下面的示例表示精确匹配，即被检索出来的文档，fruit值中的数组数据必须和查询条件完全匹配，即不能多，也不能少，顺序也必须保持一致。
db.test.find({"fruit":["apple","banana","peach"]})
下面的示例将匹配数组中指定下标元素的值。数组的起始下标是0。
db.test.find({"fruit.2":"peach"})
可以通过$size获取数组的长度，但是$size不能和比较操作符联合使用。
db.test.find({"fruit":{$size:3}})
```

内嵌文档查询：

```
    --为后面的示例构造测试数据。
    > db.test.find()
    { "_id" : ObjectId("4fd5ada3b9ac507e96276f22"), "name" : { "first" : "Joe", "last" : "He" }, "age" : 45 }
    --当嵌入式文档为数组时，需要$elemMatch操作符来帮助定位某一个元素匹配的情况，否则嵌入式文件将进行全部的匹配。
    --即检索时需要将所有元素都列出来作为查询条件方可。
    > db.test.findOne()
    {
         "_id" : ObjectId("4fd5af76b9ac507e96276f23"),
         "comments" : [
                 {
                         "author" : "joe",
                         "score" : 3
                 },
                 {
                         "author" : "mary",
                         "score" : 6
                 }
         ]
    }
    > db.test.find({"comments": {"$elemMatch": {"author":"joe","score":{"$gte":3}}}}
    { "_id" : ObjectId("4fd5af76b9ac507e96276f23"), "comments" : [ { "author" : "joe", "score" : 3 }, { "author" : "mary", "score" : 6 } ] }
```

# mongo

### 查询

```sh
db.test.findOne()
db.test.find()
#条件查询
db.test.find({"name":"stephen", "age":35})
#只查询某个字段
db.test.find({},{name:1})
```

$lt $lte $gt $gte \$ne 依次等价于< <= > >= !=

```sh
db.test.find({"age":{"$gte":18, "$lte":40}}) #年龄在 [18,40]
db.test.find({"name":{"$ne": "stephen1"}})  #不叫 stephen1
```

$in 等同于sql中的in， 但是和sql不同的是list中的数据可以属于不同类型。
$nin 等同于 sql 中的 not in,同时也是\$in 的取反

```sh
db.test.find({"name":{"$in":["stephen","stephen1"]}})
db.test.find({"name":{"$nin":["stephen2","stephen1"]}})
```

$or, $not

```sh
db.test.find({"$for":[{"name":"stephen1"},{"age":35}]})
db.test.find({"name":{"not":{"$in":["stephen2","stephen1"]}}})
```

### null 数据查询

在进行值为 null 数据的查询时，所有值为 null，以及不包含指定键的文档均会被检索出来。

```sh
db.test.find({"x":null})
```

### 正则查询

```sh
db.test.find({"name":/stephen?/i})      //i表示忽略大小写
```

### 数组数据查询

```sh
#数组中所有包含banana的文档都会被检索出来。
db.test.find({"fruit":"banana"})
#数组中必须同时包含banana和apple
db.test.find({"fruit": {"$all": ["banana","apple"]}})
#精确匹配，即被检索出来的文档，fruit值中的数组数据必须和查询条件完全匹配，即不能多，也不能少，顺序也必须保持一致。
db.test.find({"fruit":["apple","banana","peach"]})
#下面的示例将匹配数组中指定下标元素的值。数组的起始下标是0。
db.test.find({"fruit.2":"peach"})
# 可以通过$size获取数组的长度，但是$size不能和比较操作符联合使用。
db.test.find({"fruit":{$size:3}})  # 查找数组长度为3的document
```

### 内嵌文档查询：

```sh
> db.test.find()
{ "_id" : ObjectId("4fd5ada3b9ac507e96276f22"), "name" : { "first" : "Joe", "last" : "He" }, "age" : 45 }
#当嵌入式文档为数组时，需要$elemMatch操作符来帮助定位某一个元素匹配的情况，否则嵌入式文件将进行全部的匹配。
#即检索时需要将所有元素都列出来作为查询条件方可。
> db.test.findOne()
{
     "_id" : ObjectId("4fd5af76b9ac507e96276f23"),
     "comments" : [
             {
                     "author" : "joe",
                     "score" : 3
             },
             {
                     "author" : "mary",
                     "score" : 6
             }
     ]
}
> db.test.find({"comments": {"$elemMatch": {"author":"joe","score":{"$gte":3}}}}
{ "_id" : ObjectId("4fd5af76b9ac507e96276f23"), "comments" : [ { "author" : "joe", "score" : 3 }, { "author" : "mary", "score" : 6 } ] }
```

### 安全权限访问控制

1.不使用 -auth 参数

2.mongo 命令行进入，添加管理员用户

```
use admin
db.createUser({
    user: "chen",
    pwd: "12345678",
    roles: [{role: "userAdminAnyDatabase", db: "admin"}]
})
```

3.关闭 mongo 并用 -auth 参数重启

```
db.shutdownServer()
```

4.使用 admin

```
use admin
db.auth('chen','12345678') #认证，返回1表示成功
```

5.使用 admin 用户来创建用户

```
use somedb
db.createUser({
    user: "someone",
    pwd: "12345678",
    roles: [
        {role: "readWrite", db: "somedb"},
    ]
})
```

6.查看刚刚创建的用户

```
show dbs

use admin
db.system.users.find()
```

7.使用新创建的用户

```
use somedb
db.auth('someone','12345678')
```
