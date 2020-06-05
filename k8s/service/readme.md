这个service代理了携带app=hostnames标签的Pod，并且这个service的80端口，代理的是pod的9376端口。

这个应用的作用就是每次访问9376端口的时候返回它自己的hostname。

k get ep可以查看service的endpoint




## kube-proxy组件 + iptables

对于我们创建的名叫hostnames的Service来说，一旦它被提交给k8s，那么kube-proxy就可以通过Service的Informer感知到这样一个Service对象的添加，并在宿主机上创建这样一条iptables规则（你可以通过iptables-save看到它），如下所示：

    -A KUBE-SERVICES -d 10.0.1.175/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-SVC-NWV5X2332I4OT4T3

可以看到，这条iptables规则的含义是：凡是目的地址是10.0.1.175、目的端口是80的IP包，都应该跳转到另外一条名叫KUBE-SVC-NWV5X2332I4OT4T3的iptables链进行处理。这一条规则，就为这个Service设置了一个固定的入口地址。并且，由于10.0.1.175只是一条iptables规则上的配置，并没有真正的网络设备，所以你ping这个地址，是不会有任何响应的。

而KUBE-SVC-NWV5X2332I4OT4T3规则实际上是一组规则的集合，如下所示：

    -A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-WNBA2IHDGP2BOBGZ
    -A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-X3P2623AGDH6CDF3
    -A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -j KUBE-SEP-57KPRZ3JQVENLNBR

而随机转发的目的地，分别是KUBE-SEP-WNBA2IHDGP2BOBGZ、KUBE-SEP-X3P2623AGDH6CDF3和KUBE-SEP-57KPRZ3JQVENLNBR。而这三条链指向的最终目的地，其实就是这个Service代理的三个Pod。

    -A KUBE-SEP-57KPRZ3JQVENLNBR -s 10.244.3.6/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
    -A KUBE-SEP-57KPRZ3JQVENLNBR -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.3.6:9376

    -A KUBE-SEP-WNBA2IHDGP2BOBGZ -s 10.244.1.7/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
    -A KUBE-SEP-WNBA2IHDGP2BOBGZ -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.1.7:9376

    -A KUBE-SEP-X3P2623AGDH6CDF3 -s 10.244.2.3/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
    -A KUBE-SEP-X3P2623AGDH6CDF3 -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.2.3:9376

这样，访问Service VIP的IP包经过上述iptables处理之后，就已经变成了访问具体某一个后端Pod的IP包了。不难理解，这些Endpoints对应的iptables规则，正是kube-proxy通过监听Pod的变化事件，在宿主机上生成并维护的。

其实，通过上面的讲解，你可以看到，kube-proxy通过iptables处理Service的过程，其实需要在宿主机上设置相当多的iptables规则。而且，kube-proxy还需要在控制循环里不断地刷新这些规则来确保它们始终是正确的。



## IPVS模式的Service

不难想到，当你的宿主机上有大量Pod的时候，成百上千条iptables规则不断地被刷新，会大量占用该宿主机的CPU资源，甚至会让宿主机“卡”在这个过程中。所以说，**一直以来，基于iptables的Service实现，都是制约Kubernetes项目承载更多量级的Pod的主要障碍。**

IPVS模式的工作原理，其实跟iptables模式类似。当我们创建了前面的Service之后，kube-proxy首先会在宿主机上创建一个虚拟网卡（叫作：kube-ipvs0），并为它分配Service VIP作为IP地址。

而接下来，kube-proxy就会通过Linux的IPVS模块，为这个IP地址设置三个IPVS虚拟主机，并设置这三个虚拟主机之间使用轮询模式(rr)来作为负载均衡策略。我们可以通过ipvsadm查看到这个设置，如下所示：

    # ipvsadm -ln
     IP Virtual Server version 1.2.1 (size=4096)
      Prot LocalAddress:Port Scheduler Flags
        ->  RemoteAddress:Port           Forward  Weight ActiveConn InActConn
      TCP  10.102.128.4:80 rr
        ->  10.244.3.6:9376    Masq    1       0          0
        ->  10.244.1.7:9376    Masq    1       0          0
        ->  10.244.2.3:9376    Masq    1       0          0


可以看到，这三个IPVS虚拟主机的IP地址和端口，对应的正是三个被代理的Pod。

这时候，任何发往10.102.128.4:80的请求，就都会被IPVS模块转发到某一个后端Pod上了。

而相比于iptables，IPVS在内核中的实现其实也是基于Netfilter的NAT模式，所以在转发这一层上，理论上IPVS并没有显著的性能提升。但是，IPVS并不需要在宿主机上为每个Pod设置iptables规则，而是把对这些“规则”的处理放到了内核态，从而极大地降低了维护这些规则的代价。这也正印证了我在前面提到过的，“将重要操作放入内核态”是提高性能的重要手段。

> 备注：这里你可以再回顾下第33篇文章[《深入解析容器跨主机网络》](https://time.geekbang.org/column/article/65287)中的相关内容。

不过需要注意的是，IPVS模块只负责上述的负载均衡和代理功能。而一个完整的Service流程正常工作所需要的包过滤、SNAT等操作，还是要靠iptables来实现。只不过，这些辅助性的iptables规则数量有限，也不会随着Pod数量的增加而增加。

所以，在大规模集群里，我非常建议你为kube-proxy设置–proxy-mode=ipvs来开启这个功能。它为Kubernetes集群规模带来的提升，还是非常巨大的。


## DNS与service
在Kubernetes中，Service和Pod都会被分配对应的DNS A记录（从域名解析IP的记录）。

#### clusterIp模式
它的A记录的格式是：..svc.cluster.local。当你访问这条A记录的时候，它解析到的就是该Service的VIP地址。

对于ClusterIP模式的Service来说，它代理的Pod被自动分配的A记录的格式是：..pod.cluster.local。这条记录指向Pod的IP地址。

#### Headless Service (指定了clusterIP=None)
它的A记录的格式也是：..svc.cluster.local。但是，当你访问这条A记录的时候，它返回的是所有被代理的Pod的IP地址的集合。

而对Headless Service来说，它代理的Pod被自动分配的A记录的格式是：...svc.cluster.local。这条记录也指向Pod的IP地址。

但如果你为Pod指定了Headless Service，并且Pod本身声明了hostname和subdomain字段，那么这时候Pod的A记录就会变成：<pod的hostname>...svc.cluster.local，比如：

    apiVersion: v1
    kind: Service
    metadata:
      name: default-subdomain
    spec:
      selector:
        name: busybox
      clusterIP: None
      ports:
      - name: foo
        port: 1234
        targetPort: 1234
    ---
    apiVersion: v1
    kind: Pod
    metadata:
      name: busybox1
      labels:
        name: busybox
    spec:
      hostname: busybox-1
      subdomain: default-subdomain
      containers:
      - image: busybox
        command:
          - sleep
          - "3600"
        name: busybox


在上面这个Service和Pod被创建之后，你就可以通过busybox-1.default-subdomain.default.svc.cluster.local解析到这个Pod的IP地址了。

需要注意的是，在Kubernetes里，/etc/hosts文件是单独挂载的，这也是为什么kubelet能够对hostname进行修改并且Pod重建后依然有效的原因。这跟Docker的Init层是一个原理。





所谓Service的访问入口，其实就是每台宿主机上由kube-proxy生成的iptables规则，以及kube-dns生成的DNS记录。而一旦离开了这个集群，这些信息对用户来说，也就自然没有作用了。

# nodeport

需要注意的是，在NodePort方式下，Kubernetes会在IP包离开宿主机发往目的Pod时，对这个IP包做一次SNAT操作，将这个IP包的源地址替换成了这台宿主机上的CNI网桥地址，或者宿主机本身的IP地址（如果CNI网桥不存在的话）。


    -A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE

当然，这个SNAT操作只需要对Service转发出来的IP包进行（否则普通的IP包就被影响了）。而iptables做这个判断的依据，就是查看该IP包是否有一个“0x4000”的“标志”。你应该还记得，这个标志正是在IP包被执行DNAT操作之前被打上去的。

可是，**为什么一定要对流出的包做SNAT****操作****呢？**

这里的原理其实很简单，如下所示：

               client
                 \ ^
                  \ \
                   v \
       node 1 <--- node 2
        | ^   SNAT
        | |   --->
        v |
     endpoint


当一个外部的client通过node 2的地址访问一个Service的时候，node 2上的负载均衡规则，就可能把这个IP包转发给一个在node 1上的Pod。这里没有任何问题。

而当node 1上的这个Pod处理完请求之后，它就会按照这个IP包的源地址发出回复。

可是，如果没有做SNAT操作的话，这时候，被转发来的IP包的源地址就是client的IP地址。**所以此时，Pod就会直接将回复发****给****client。**对于client来说，它的请求明明发给了node 2，收到的回复却来自node 1，这个client很可能会报错。

所以，在上图中，当IP包离开node 2之后，它的源IP地址就会被SNAT改成node 2的CNI网桥地址或者node 2自己的地址。这样，Pod在处理完成之后就会先回复给node 2（而不是client），然后再由node 2发送给client。

当然，这也就意味着这个Pod只知道该IP包来自于node 2，而不是外部的client。对于Pod需要明确知道所有请求来源的场景来说，这是不可以的。

所以这时候，你就可以将Service的spec.externalTrafficPolicy字段设置为local，这就保证了所有Pod通过Service收到请求之后，一定可以看到真正的、外部client的源地址。

而这个机制的实现原理也非常简单：**这时候，一台宿主机上的iptables规则，会设置为只将IP包转发给运行在这台宿主机上的Pod**。所以这时候，Pod就可以直接使用源地址将回复包发出，不需要事先进行SNAT了。这个流程，如下所示：

           client
           ^ /   \
          / /     \
         / v       X
       node 1     node 2
        ^ |
        | |
        | v
     endpoint


当然，这也就意味着如果在一台宿主机上，没有任何一个被代理的Pod存在，比如上图中的node 2，那么你使用node 2的IP地址访问这个Service，就是无效的。此时，你的请求会直接被DROP掉。

## LoadBalancer

从外部访问Service的第二种方式，适用于公有云上的Kubernetes服务。这时候，你可以指定一个LoadBalancer类型的Service，如下所示：

    ---
    kind: Service
    apiVersion: v1
    metadata:
      name: example-service
    spec:
      ports:
      - port: 8765
        targetPort: 9376
      selector:
        app: example
      type: LoadBalancer


在公有云提供的Kubernetes服务里，都使用了一个叫作CloudProvider的转接层，来跟公有云本身的 API进行对接。所以，在上述LoadBalancer类型的Service被提交后，Kubernetes就会调用CloudProvider在公有云上为你创建一个负载均衡服务，并且把被代理的Pod的IP地址配置给负载均衡服务做后端。

### ExternalName
在1.7之后支持，举个例子：

    kind: Service
    apiVersion: v1
    metadata:
      name: my-service
    spec:
      type: ExternalName
      externalName: my.database.example.com


在上述Service的YAML文件中，我指定了一个externalName=my.database.example.com的字段。而且你应该会注意到，这个YAML文件里不需要指定selector。

这时候，当你通过Service的DNS名字访问它的时候，比如访问：my-service.default.svc.cluster.local。那么，Kubernetes为你返回的就是`my.database.example.com`。所以说，ExternalName类型的Service，其实是在kube-dns里为你添加了一条CNAME记录。这时，访问my-service.default.svc.cluster.local就和访问my.database.example.com这个域名是一个效果了。

此外，Kubernetes的Service还允许你为Service分配公有IP地址，比如下面这个例子：

    kind: Service
    apiVersion: v1
    metadata:
      name: my-service
    spec:
      selector:
        app: MyApp
      ports:
      - name: http
        protocol: TCP
        port: 80
        targetPort: 9376
      externalIPs:
      - 80.11.12.10


在上述Service中，我为它指定的externalIPs=80.11.12.10，那么此时，你就可以通过访问80.11.12.10:80访问到被代理的Pod了。不过，**在这里Kubernetes要求externalIPs必须是至少能够路由到一个Kubernetes的节点**。

## 常见问题
实际上，在理解了Kubernetes Service机制的工作原理之后，很多与Service相关的问题，其实都可以通过分析Service在宿主机上对应的iptables规则（或者IPVS配置）得到解决。

比如，当你的Service没办法通过DNS访问到的时候。你就需要区分到底是Service本身的配置问题，还是集群的DNS出了问题。一个行之有效的方法，就是检查Kubernetes自己的Master节点的Service DNS是否正常：

    # 在一个Pod里执行
    $ nslookup kubernetes.default
    Server:    10.0.0.10
    Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

    Name:      kubernetes.default
    Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local


如果上面访问kubernetes.default返回的值都有问题，那你就需要检查kube-dns的运行状态和日志了。否则的话，你应该去检查自己的 Service 定义是不是有问题。

而如果你的Service没办法通过ClusterIP访问到的时候，你首先应该检查的是这个Service是否有Endpoints：

    $ kubectl get endpoints hostnames
    NAME        ENDPOINTS
    hostnames   10.244.0.5:9376,10.244.0.6:9376,10.244.0.7:9376


需要注意的是，如果你的Pod的readniessProbe没通过，它也不会出现在Endpoints列表里。

而如果Endpoints正常，那么你就需要确认kube-proxy是否在正确运行。在我们通过kubeadm部署的集群里，你应该看到kube-proxy输出的日志如下所示：

    I1027 22:14:53.995134    5063 server.go:200] Running in resource-only container "/kube-proxy"
    I1027 22:14:53.998163    5063 server.go:247] Using iptables Proxier.
    I1027 22:14:53.999055    5063 server.go:255] Tearing down userspace rules. Errors here are acceptable.
    I1027 22:14:54.038140    5063 proxier.go:352] Setting endpoints for "kube-system/kube-dns:dns-tcp" to [10.244.1.3:53]
    I1027 22:14:54.038164    5063 proxier.go:352] Setting endpoints for "kube-system/kube-dns:dns" to [10.244.1.3:53]
    I1027 22:14:54.038209    5063 proxier.go:352] Setting endpoints for "default/kubernetes:https" to [10.240.0.2:443]
    I1027 22:14:54.038238    5063 proxier.go:429] Not syncing iptables until Services and Endpoints have been received from master
    I1027 22:14:54.040048    5063 proxier.go:294] Adding new service "default/kubernetes:https" at 10.0.0.1:443/TCP
    I1027 22:14:54.040154    5063 proxier.go:294] Adding new service "kube-system/kube-dns:dns" at 10.0.0.10:53/UDP
    I1027 22:14:54.040223    5063 proxier.go:294] Adding new service "kube-system/kube-dns:dns-tcp" at 10.0.0.10:53/TCP



