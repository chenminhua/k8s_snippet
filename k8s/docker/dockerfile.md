FROM ubuntu
MAINTAINER bigtom hi@chenminhua.com
RUN echo "deb http://archive.ubuntu.com/ubuntu/ raring main universe" >> /etc/apt/sources.list
RUN apt-get update && apt-get install -y nginx  命令RUN会被翻译为"/bin/sh -c blahblah"
RUN echo "\ndaemon off;" >> /etc/nginx/nginx.conf
EXPOSE 80 暴露端口
WORKDIR   指定工作目录
USER      指定当前用户
HEALTHCHECK 健康检查
VOLUME /data     创建一个挂载点，一般用来存放数据库或者需要永久保存的数据
ENV NODE_ENV=development  指定一个环境变量
ARG                       设置环境变量（不会保存到容器运行时）
ADD指令   更高级的COPY,建议使用COPY
COPY <src> <dst>     复制本机目录/文件到容器中
ENTRYPOINT指令    每个dockerfile只能有一个ENTRYPOINT
CMD /usr/sbin/nginx  CMD命令指定启动容器时的命令。

一般情况下，Dockerfile由4部分组成：基础镜像信息，维护者信息，镜像操作指令和容器启动指令。

注意： 每个Dockerfile只能有一条CMD指令(容器就是一个进程)。如果有多个CMD命令，只执行最后一条。对于容器而言，启动容器就是启动容器应用进程，容器就是为主进程而存在的。容器中的应用应该在前台执行。

另外，在使用 Dockerfile 时，你可能还会看到一个叫作 ENTRYPOINT 的原语。实际上，它和 CMD 都是 Docker 容器进程启动所必需的参数，完整执行格式是：“ENTRYPOINT CMD”。
但是，默认情况下，Docker 会为你提供一个隐含的 ENTRYPOINT，即：/bin/sh -c。所以，在不指定 ENTRYPOINT 时，比如在我们这个例子里，实际上运行在容器里的完整进程是：/bin/sh -c “python app.py”，即 CMD 的内容就是 ENTRYPOINT 的参数。
备注：基于以上原因，我们后面会统一称 Docker 容器的启动进程为 ENTRYPOINT，而不是 CMD。


