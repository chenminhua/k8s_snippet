yum -y install java

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

让 es 支持外网访问
network.host: 0.0.0.0

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
