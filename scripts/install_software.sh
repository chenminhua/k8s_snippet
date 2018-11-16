#!/bin/bash
yum update -y
yum install epel-release -y
yum update -y
yum install git -y
yum install zsh -y
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

yum install dstat -y
yum install epel-release -y
yum install python-pip -y

## docker

yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce-18.06.0.ce -y
systemctl enable docker
systemctl start docker

# 临时关闭selinux,完全关闭需要修改/etc/selinux/config 文件,将 SELINUX=enforcing 改为 SELINUX=disabled并重启机器
setenforce 0

## 安装 kubenetes, kubelet， kubectl, kubeadm
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet && systemctl start kubelet

# 我喜欢用k来作为kubectl的别名
echo 'alias k="kubectl"' >> ~/.zshrc
source ~/.zshrc
