wget http://apache.claz.org/hadoop/common/hadoop-2.9.2/hadoop-2.9.2.tar.gz
tar -xzf hadoop-2.9.2.tar.gz

export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk

# 单机quickstart
cd hadoop-2.9.2
mkdir input
cp etc/hadoop/*.xml input
bin/hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-2.9.2.jar grep input output 'dfs[a-z.]+'
cat output/*


