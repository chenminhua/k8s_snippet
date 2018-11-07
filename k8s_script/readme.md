i
## 在 ata-op1 机器上搭建 k8s master

kubeadm init

kubeadm 还会提示我们第一次使用 Kubernetes 集群需要的配置命令，其实就是将配置文件拷贝到当前用户的家目录下，kubectl 默认会使用这个目录下的信息来访问集群。

```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubenetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
## 同时也可以将配置文件拷贝到其他机器上，包括你自己的开发电脑上
```

然后运行 k get nodes 查看现在有多少节点。应该还只有一个，而且状态是 NotReady。通过 k describe node ata-op1 我们发现，master not ready 是因为我们还没有网络插件。那我们就来一键部署网络插件

k apply -f https://git.io/weave-kube-1.6

等一会儿，所有的系统 pod 就都可以启动了。k get nodes 看一下，我们发现 master 也起来了。

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

