## 容器化守护进程的意义：DaemonSet

这个 DaemonSet，管理的是一个 fluentd-elasticsearch 镜像的 Pod。这个镜像的功能非常实用：通过 fluentd 将 Docker 容器里的日志转发到 ElasticSearch 中。

而这些 Pod 的模板，也是用 template 字段定义的。在这个字段中，我们定义了一个使用 fluentd-elasticsearch:1.20 镜像的容器，而且这个容器挂载了两个 hostPath 类型的 Volume，分别对应宿主机的/var/log 目录和/var/lib/docker/containers 目录。显然，fluentd 启动之后，它会从这两个目录里搜集日志信息，并转发给 ElasticSearch 保存。这样，我们通过 ElasticSearch 就可以很方便地检索这些日志了。

需要注意的是，Docker 容器里应用的日志，默认会保存在宿主机的/var/lib/docker/containers/{{.容器ID}}/{{.容器ID}}-json.log 文件里，所以这个目录正是 fluentd 的搜集目标。

## DaemonSet 又是如何保证每个 Node 上有且只有一个被管理的 Pod 呢？

这是一个典型的“控制器模型”能够处理的问题。DaemonSet Controller，首先从 Etcd 里获取所有的 Node 列表，然后遍历所有的 Node。这时，它就可以很容易地去检查，当前这个 Node 上是不是有一个携带了 name=fluentd-elasticsearch 标签的 Pod 在运行。没有则创建，多了就删除。但是，如何在指定的 Node 上创建新 Pod 呢？答案是 nodeAffinity。我来举个例子：

```
apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: metadata.name
            operator: In
            values:
            - node-geektime
```

在这个 Pod 里，我声明了一个 spec.affinity 字段，然后定义了一个 nodeAffinity。其中，spec.affinity 字段，是 Pod 里跟调度相关的一个字段。而这里的 nodeAffinity 的含义是：

1.  requiredDuringSchedulingIgnoredDuringExecution：它的意思是说，这个 nodeAffinity 必须在每次调度的时候予以考虑。同时，这也意味着你可以设置在某些情况下不考虑这个 nodeAffinity；

2.  这个 Pod，将来只允许运行在“`metadata.name`”是“node-geektime”的节点上。

所以，**我们的 DaemonSet Controller 会在创建 Pod 的时候，自动在这个 Pod 的 API 对象里，加上这样一个 nodeAffinity 定义**。其中，需要绑定的节点名字，正是当前正在遍历的这个 Node。

当然，DaemonSet 并不需要修改用户提交的 YAML 文件里的 Pod 模板，而是在向 Kubernetes 发起请求之前，直接修改根据模板生成的 Pod 对象。

此外，DaemonSet 还会给这个 Pod 自动加上另外一个与调度相关的字段，叫作 tolerations。这个字段意味着这个 Pod，会“容忍”（Toleration）某些 Node 的“污点”（Taint）。

而 DaemonSet 自动加上的 tolerations 字段，格式如下所示：

    apiVersion: v1
    kind: Pod
    metadata:
      name: with-toleration
    spec:
      tolerations:
      - key: node.kubernetes.io/unschedulable
        operator: Exists
        effect: NoSchedule

这个 Toleration 的含义是：“容忍”所有被标记为 unschedulable“污点”的 Node；“容忍”的效果是允许调度。

而在正常情况下，被标记了 unschedulable“污点”的 Node，是不会有任何 Pod 被调度上去的（effect: NoSchedule）。可是，DaemonSet 自动地给被管理的 Pod 加上了这个特殊的 Toleration，就使得这些 Pod 可以忽略这个限制，继而保证每个节点上都会被调度一个 Pod。当然，如果这个节点有故障的话，这个 Pod 可能会启动失败，而 DaemonSet 则会始终尝试下去，直到 Pod 启动成功。

假如当前 DaemonSet 管理的，是一个网络插件的 Agent Pod，那么你就必须在这个 DaemonSet 的 YAML 文件里，给它的 Pod 模板加上一个能够“容忍”`node.kubernetes.io/network-unavailable`“污点”的 Toleration。正如下面这个例子所示：

```
spec:
  tolerations:
  - key: node.kubernetes.io/network-unavailable
    operator: Exists
    effect: NoSchedule
```

**而通过这样一个 Toleration，调度器在调度这个 Pod 的时候，就会忽略当前节点上的“污点”，从而成功地将网络插件的 Agent 组件调度到这台机器上启动起来。**

这种机制，正是我们在部署 Kubernetes 集群的时候，能够先部署 Kubernetes 本身、再部署网络插件的根本原因：因为当时我们所创建的 Weave 的 YAML，实际上就是一个 DaemonSet。

当然，**你也可以在 Pod 模板里加上更多种类的 Toleration，从而利用 DaemonSet 实现自己的目的**。比如，在这个 fluentd-elasticsearch DaemonSet 里，我就给它加上了这样的 Toleration：

    tolerations:
    - key: node-role.kubernetes.io/master
      effect: NoSchedule

这是因为在默认情况下，Kubernetes 集群不允许用户在 Master 节点部署 Pod。因为，Master 节点默认携带了一个叫作`node-role.kubernetes.io/master`的“污点”。所以，为了能在 Master 节点上部署 DaemonSet 的 Pod，我就必须让这个 Pod“容忍”这个“污点”。

## 总结

相比于 Deployment，DaemonSet 只管理 Pod 对象，然后通过 nodeAffinity 和 Toleration 这两个调度器的小功能，保证了每个节点上有且只有一个 Pod。

与此同时，DaemonSet 使用 ControllerRevision，来保存和管理自己对应的“版本”。这种“面向 API 对象”的设计思路，大大简化了控制器本身的逻辑，也正是 Kubernetes 项目“声明式 API”的优势所在。
