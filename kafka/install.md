wget https://www-eu.apache.org/dist/kafka/2.1.0/kafka_2.11-2.1.0.tgz

tar -xzf kafka_2.11-2.1.0.tgz

bin/zookeeper-server-start.sh config/zookeeper.properties  启动zk

bin/kafka-server-start.sh config/server.properties  启动kafka


