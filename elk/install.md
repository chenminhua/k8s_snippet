yum -y install java-1.8.0-openjdk.x86_64

## elasticsearch

sudo rpm --import http://packages.elastic.co/GPG-KEY-elasticsearch

vi /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

yum -y install elasticsearch

#### 配置 elasticsearch

修改 /etc/elasticsearch/elasticsearch.yaml
cluster.name: es-prod
node.name: node-1
discovery.zen.ping.unicast.hosts: ["ata-op1", "ata-op2", "ata-op3"]
http.port: 9200

让 es 支持外网访问
network.host: 0.0.0.0

#### 启动 elasticsearch

systemctl enable elasticsearch
systemctl start elasticsearch

验证 curl localhost:9200/\_cluster/state

## logstash

rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

vi /etc/yum.repos.d/logstash.repo
[logstash-6.x]
name=Elastic repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

#### 配置文件

修改/etc/logstash/logstash.yml
path.logs: /var/log/logstash
xpack.monitoring.elasticsearch.url: "http://10.1.50.4:9200"
xpack.monitoring.elasticsearch.username: logstash_system
xpack.monitoring.elasticsearch.password: logstashpassword

#### 启动 logstash

systemctl enable logstash
systemctl start logstash

## kibana

/etc/yum.repos.d/kibana.repo
[kibana-6.x]
name=Kibana repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md

yum -y install kibana

## filebeat

wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.5.4-x86_64.rpm

rpm -vi filebeat-6.5.4-x86_64.rpm

systemctl enable filebeat
systemctl start filebeat

下载测试文件
wget https://download.elastic.co/demos/logstash/gettingstarted/logstash-tutorial.log.gz
gunzip logstash-tutorial.log.gz

编写 /etc/logstash/conf.d/first-pipeline.conf

```
input {
    beats {
        port => "5044"
    }
}
output {
    stdout { codec => rubydebug }
}
```

测试 conf

/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/first-pipeline.conf --config.test_and_exit

使用这个 pipeline
bin/logstash -f /etc/logstash/conf.d/first-pipeline.conf --config.reload.automatic

启动 filebeat
bin/filebeat -e -c /etc/filebeat/filebeat.yml -d "publish"

#### 测试 filter

```
input {
    beats {
        port => "5044"
    }
}
filter {
    grok {
        match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
}
output {
    stdout { codec => rubydebug }
}
```

rm -f /usr/share/filebeat/bin/data/registry

使用这个 pipeline
bin/logstash -f /etc/logstash/conf.d/first-pipeline.conf --config.reload.automatic

启动 filebeat
bin/filebeat -e -c /etc/filebeat/filebeat.yml -d "publish"

#### 存入 elasticsearch

```
input {
    beats {
        port => "5044"
    }
}
filter {
    grok {
        match => { "message" => "%{COMBINEDAPACHELOG}" }
    }
    geoip {
        source => "clientip"
    }
}
output {
    elasticsearch {
        hosts => [ "localhost:9200" ]
    }
}
```

curl 'http://localhost:9200/_cat/indices?v'

#### 配置文件

vi /etc/filebeat/fiilebeat.yml
