docker build -t helloworld .

docker image inspect <imgid>

docker run -p 4000:80 helloworld

重新打tag
docker tag helloworld chenminhua/helloworld:v1

docker chenminhua/helloworld:v1

查看容器对应的pid
docker inspect --format '{{ .State.Pid }}' <container_id>

ls -l /proc/<pid>/ns
