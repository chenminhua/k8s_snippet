# 可以考虑先改掉sshd的端口

sudo docker run --detach \
	--hostname gitlab.example.com \
	--publish 443:443 --publish 80:80 --publish 22:22 \
	--name gitlab \
	--restart always \
	--volume /srv/gitlab/config:/etc/gitlab \
	--volume /srv/gitlab/logs:/var/log/gitlab \
	--volume /srv/gitlab/data:/var/opt/gitlab \
	gitlab/gitlab-ce:latest

首次运行可能要等一段时间才行,三五分钟吧，然后登陆web，设置root密码。然后就可以登陆了。

所有数据都在/srv/gitlab/下

# 将gitlab跑在不同端口上
sudo docker run --detach \
	--hostname gitlab.example.com \
	--publish 8929:80 --publish 2289:22 \
	--name gitlab \
	--restart always \
	--volume /srv/gitlab/config:/etc/gitlab \
	--volume /srv/gitlab/logs:/var/log/gitlab \
	--volume /srv/gitlab/data:/var/opt/gitlab \
	gitlab/gitlab-ce:latest


