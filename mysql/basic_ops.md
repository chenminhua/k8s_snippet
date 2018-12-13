# 安装 mysql 5.7

```
wget https://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm
rpm -ivh mysql57-community-release-el7-9.noarch.rpm
yum install mysql-server -y
```

# 修改 root 密码

```
vi /etc/my.cnf
加上一行 skip-grant-tables

启动 service mysqld start

update mysql.user set authentication_string = password('!234qwerASDF') where user='root';
flush privileges

vi /etc/my.cnf 删除 skip-grant-tables
service mysqld restart
```

# 开启 binlog

```
log-bin=/var/lib/mysql/mysql-bin
server-id=1
```

# 修改 datadir

```
cp -r /var/lib/mysql /data
chown -R mysql:mysql /data/mysql
vi /etc/my.cnf 修改 datadir 和 socket 配置
setenforce 0
service mysqld restart
```

## schema 同步与比较

http://seanlook.com/2017/11/02/mysql_schemasync/
https://github.com/mmatuson/SchemaSync

## 执行 sql 脚本

mysql -D db_name -u username -p < example.sql
