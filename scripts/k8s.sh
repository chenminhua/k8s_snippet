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


## 在 ata-op1 机器上搭建 k8s master

kubeadm init

```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubenetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
## 同时也可以将配置文件拷贝到其他机器上，包括你自己的开发电脑上
```

k apply -f https://git.io/weave-kube-1.6

## 部署 k8s worker

使用 kubeadm 部署 worker 很简单，使用部署 master 时候命令行返回给你的那条命令就行了

```sh
kubeadm join 10.0.0.10:6443 --token 5nxo6z.w774jzvsscx13gkx --discovery-token-ca-cert-hash sha256:e698d39975432125c035f8892607e1c70888d8f3c6460da207a3c96b014923be
```

## 部署 dashboard

```
k apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
k proxy
```

## 部署存储插件

很多时候我们需要用数据卷（Volume）把外面宿主机上的目录或者文件挂载进容器的 Mount Namespace 中，从而达到容器和宿主机共享这些目录或者文件的目的。可是，如果你在某一台机器上启动的一个容器，显然无法看到其他机器上的容器在它们的数据卷里写入的文件。**这是容器最典型的特征之一：无状态。**

而容器的持久化存储，就是用来保存容器存储状态的重要手段：存储插件会在容器里挂载一个基于网络或者其他机制的远程数据卷，使得在容器里创建的文件，实际上是保存在远程存储服务器上，或者以分布式的方式保存在多个节点上，而与当前宿主机没有任何绑定关系。这样，无论你在其他哪个宿主机上启动新的容器，都可以请求挂载指定的持久化存储卷，从而访问到数据卷里保存的内容。**这就是“持久化”的含义。**

Rook 项目是一个基于 Ceph 的 Kubernetes 存储插件（它后期也在加入对更多存储实现的支持）。不过，不同于对 Ceph 的简单封装，Rook 在自己的实现中加入了水平扩展、迁移、灾难备份、监控等大量的企业级功能，使得这个项目变成了一个完整的、生产级别可用的容器存储插件。

得益于容器化技术，用两条指令，Rook 就可以把复杂的 Ceph 存储后端部署起来：

```sh
k apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml
k apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml

## 在部署完成后，你就可以看到Rook项目会将自己的Pod放置在由它自己管理的两个Namespace当中：
kubectl get pods -n rook-ceph-system
kubectl get pods -n rook-ceph
```

这样，一个基于 Rook 持久化存储集群就以容器的方式运行起来了，而接下来在 Kubernetes 项目上创建的所有 Pod 就能够通过 Persistent Volume（PV）和 Persistent Volume Claim（PVC）的方式，在容器里挂载由 Ceph 提供的数据卷了。而 Rook 项目，则会负责这些数据卷的生命周期管理、灾难备份等运维工作。
