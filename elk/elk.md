# logstash

logstash 需要有 input,output 和可选的 filter

### quick start

bin/logstash -e 'input{stdin{}}output{stdout{}}'
bin/logstash -e 'input{stdin{}}output{stdout{codec=>rubydebug}}'

### 数据解析

Filebeat 客户端用于从文件中收集日志并传到 Logstash。默认和 logstash 一起安装。

### 配置语法

shipper, broker, indexer 三种角色

### 区段 section

input {
stdin {}
syslog {}
}

## 数据类型

bool, debug => true
string, host => "hostname"
number, port => 514
array, match => ["datetime", "UNIX", "ISO8601"]
hash. options => { key1 => "value1", key2 => "value2" }

## 字段引用

the longitude is %{[geoip][location][0]}

## 条件判断

## 命令行参数

-e 执行
-f 配置文件
-l 日志

## 设置文件

在 \$LS_HOME/config/logstash.yml 文件

```
pipeline:
    workers: 24
    batch:
        size: 125
        delay: 5
```

# plugin 安装

bin/logstash-plugin list 查看插件
bin/logstash-plugin install ...
bin/logstash-plugin update ...

# 长期运行

service 运行管理
nohup
SCREEN
supervisord 等

# 输入插件

默认使用 input/stdin
也可以读取文件

```
input {
    stdin {
        add_field => {"key" => "value"}
        codec => "plain"
        tags => ["add"]
        type => "std"
    }
    file {
        path => ["/var/log/*.log"]
        type => "system"
        start_position => "beginning"
    }
}
discover_interval  指定监听间隔
exclude  排除不想被监听的文件
close_older  关闭长期不更新的文件的监听
```

一个例子

```
input {
    stdin {
        type => "web"
    }
}
filter {
    if [type] == "web" {
        grok {
            match => ["message", %{COMBINEDAPACHELOG}]
        }
    }
}
```

## 读取 syslog 数据

## 读取网络数据

```
input {
    tcp {
        port => 8888
        mode => "server"
        ssl_enable => false
    }
}
```

# 编码插件 codec

input | decode | filter | encode | output

# 过滤器插件 Filter

filters/date 插件可以用来转换日志记录中的时间字符串，变成 logStash::Timestamp 对象，然后存到@timestamp 字段
