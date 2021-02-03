# Galaxy

> [Galaxy插件](https://github.com/tkestack/galaxy) 是腾讯开源的一个 Kubernetes 网络项目，旨在为 Pod 提供 overlay 和高性能 underlay 网络。并且它还实现了浮动IP(或弹性IP), 即Pod的IP即使由于节点崩溃而飘到另一个节点上也不会改变，这对于运行有状态集合应用程序非常有利。

galaxy组件由三个组件组成: Galaxy，CNI插件和Galaxy IPAM。

- Galaxy：在每个kubelet节点上运行的守护进程，该进程调用不同种类的CNI插件来设置Pod所需的网络。
- CNI插件
- Galaxy IPAM：是Kubernetes Scheduler插件(Scheduler Extender方式扩展)，可以用作浮动IP配置和IP分配管理器。

**亮点:**

- pod ip 使用宿主机网段, 能够实现集群外 pod ip 直接访问, 对于 dubbo 服务来说相当友好!
- 能够固定 IP, 对于容器化改造初期业务对于 IP 的依赖较重的情况下非常友好!

## 1. galaxy 部署

Galaxy网络方案主要包括两个模块：

- galaxy：以daemonset形式存在每个k8s集群的节点上，它通过判断pod annotation信息，来设定pod网络是用固定ip还是非固定ip
- galaxy-ipam：根据pod的生命周期，完成pod ip的分配、释放、已分配ip信息的记录等功能

## 1.1 galaxy 启动参数配置说明

galaxy 工作原理图![galaxy 工作原理图](https://github.com/currycan/galaxy/raw/master/doc/image/galaxy.png)

工作流程:

1. Flannel为每个节点分配一个子网并将其保存在etcd和/run/flannel/subnet.env文件中
2. Kubelet根据CNI配置启动SDN CNI进程。
3. SDN CNI进程通过unix套接字使用来自Kubelet的所有args调用Galaxy。
4. Galaxy调用Flannel CNI从/run/flannel/subnet.env解析子网信息。
5. Flannel CNI调用网桥CNI或Veth CNI来为POD配置网络。

Galaxy 支持云上部署和 IDC 部署, 针对不同环境启动参数不同.

需要注意的参数主要是:

- `--route-eni` 云上需要开启即配置该参数
- `network-policy` network policy 根据需要开启, 建议开启
- `alsologtostderr` 日志打印 stdout, 建议开启
- `-v` 日志级别,建议设置为 3

因此[Galaxy k8s 配置清单](galaxy.yaml)中给出的是 IDC 环境参数:

```yaml
        command: ["/bin/sh"]
        # private-cloud should run without --route-eni
        args: ["-c", "cp -p /etc/galaxy/cni/00-galaxy.conf /etc/cni/net.d/; cp -p /opt/cni/galaxy/bin/galaxy-sdn /opt/cni/galaxy/bin/loopback /opt/cni/bin/; /usr/bin/galaxy --network-policy --logtostderr=true --v=3"]
```

## 1.2 galaxy 配置说明

### 1.2.1 00-galaxy.conf 配置

部署过程中,由于未指定 name 字段服务启动失败, 因此需要指定配置名称,可以与类型保持一致.

### 1.2.2 galaxy.json 配置

Galaxy支持多个网络模式，通过设置 DefaultNetworks 网络来选取默认网络模式.

参考示例:

```json
{
  "NetworkConf":[
    {"name":"tke-route-eni", "type":"tke-route-eni", "eni":"eth1", "routeTable":1},
    {"name":"galaxy-flannel", "type":"galaxy-flannel", "delegate":{"type":"galaxy-veth"}, "subnetFile":"/run/flannel/subnet.env"},
    {"name":"galaxy-k8s-vlan", "type":"galaxy-k8s-vlan", "device":"eth1", "default_bridge_name": "br0"},
    {"name": "galaxy-k8s-sriov", "type": "galaxy-k8s-sriov", "device": "eth1", "vf_num": 10},
    {"name":"galaxy-underlay-veth", "type":"galaxy-underlay-veth", "device":"eth1"}
  ],
  "DefaultNetworks": ["galaxy-flannel"],
  "ENIIPNetwork": "galaxy-k8s-vlan"
}
```

**Tips:**

- 网卡设备的名称一定要根据实际环境配置, 默认是 eth1(根据需要修改如: ens192)
- 如果网络名称为空，则Galaxy将使用 type 作为网络名称。 当Pod需要指定的网络模式时，通过指定 NetworkConf 的 name 即可.
- `DefaultNetworks` 字段定义默认将使用哪种网络模式, 即在没有通过注解指定网络模式时默认选用的网络模式
- `ENIIPNetwork` 字段定义的是当使用eni ip(辅助网卡)时,默认选用的网络模式, 建议使用 underlay 模式也就是galaxy-underlay-veth

注解的具体使用方式如下:

| Pod Annotation                      | Usage                                                        | Expain                                                                           |
| ----------------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------- |
| k8s.v1.cni.cncf.io/networks         | k8s.v1.cni.cncf.io/networks: galaxy-flannel,galaxy-k8s-sriov | 使用了注解指定了网络模式,否则将使用 DefaultNetworks 默认值                       |
| k8s.v1.cni.galaxy.io/release-policy | k8s.v1.cni.galaxy.io/release-policy: never, immutable        | 使用 eni ip 时, ip 回收策略,如不指定 pod 删除后将回收, never 表示不回收即固定 IP |

## 2. galaxy-ipam 部署

### 2.1 工作原理

![工作原理](https://github.com/currycan/galaxy/raw/master/doc/image/galaxy-ipam.png)

![process](https://github.com/currycan/galaxy/raw/master/doc/image/galaxy-ipam-scheduling-process.png)

Galaxy-ipam 是 [Kubernetes Scheudler](https://kubernetes.io/zh/docs/concepts/extend-kubernetes/extend-cluster/) 的扩展器。 调度程序通过HTTP调用Galaxy-ipam进行过滤和绑定，因此我们需要创建调度程序策略配置。

### 2.1 scheduler-policy configMap 配置

kube-scheduler 增加 [configmap](scheduler-policy.yaml) 配置:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: scheduler-policy
  namespace: kube-system
data:
  policy.cfg: |
    {
      "kind": "Policy",
      "apiVersion": "v1",
      "extenders": [
        {
          "urlPrefix": "http://127.0.0.1:9040/v1",
          "httpTimeout": 10000000000,
          "filterVerb": "filter",
          "BindVerb": "bind",
          "weight": 1,
          "enableHttps": false,
          "managedResources": [
            {
              "name": "tke.cloud.tencent.com/eni-ip",
              "ignoredByScheduler":  true
            }
          ]
        }
      ]
    }
```

**Tips:**

- `urlPrefix` 需要指定 galaxy-ipam 服务的地址, 支持 cluster IP 和 nodePort 方式, 建议可以固定 cluster ip 使用 cluster ip
- `ignoredByScheduler` 字段在 IDC 环境中一定要配置为 true

配置完 `kube-scheduler` 的 `policy-configmap` 后需要修改 kube-scheduler 配置清单(/etc/kubernetes/manifests/kube-scheduler.yaml), 启动命令中加入 `--policy-configmap=scheduler-policy`, 另外 kube-scheduler 并没有有访问configmap的权限，会报没有权限访问 configmap, 因此在重启 `kube-scheduler` 之前需要修改 clusterrole, 在最后面添加:

```yaml
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
  - list
  - watch
  - update
  - create
  - patch
```

修改之后查看权限:

```bash
# kubectl describe clusterrole system:kube-scheduler

Name:         system:kube-scheduler
Labels:       kubernetes.io/bootstrapping=rbac-defaults
Annotations:  rbac.authorization.kubernetes.io/autoupdate: true
PolicyRule:
  Resources                                  Non-Resource URLs  Resource Names    Verbs
  ---------                                  -----------------  --------------    -----
  events                                     []                 []                [create patch update]
  events.events.k8s.io                       []                 []                [create patch update]
  bindings                                   []                 []                [create]
  endpoints                                  []                 []                [create]
  pods/binding                               []                 []                [create]
  tokenreviews.authentication.k8s.io         []                 []                [create]
  subjectaccessreviews.authorization.k8s.io  []                 []                [create]
  leases.coordination.k8s.io                 []                 []                [create]
  pods                                       []                 []                [delete get list watch]
  configmaps                                 []                 []                [get list watch update create patch]
  nodes                                      []                 []                [get list watch]
  persistentvolumeclaims                     []                 []                [get list watch]
  persistentvolumes                          []                 []                [get list watch]
  replicationcontrollers                     []                 []                [get list watch]
  services                                   []                 []                [get list watch]
  replicasets.apps                           []                 []                [get list watch]
  statefulsets.apps                          []                 []                [get list watch]
  replicasets.extensions                     []                 []                [get list watch]
  poddisruptionbudgets.policy                []                 []                [get list watch]
  csinodes.storage.k8s.io                    []                 []                [get list watch]
  endpoints                                  []                 [kube-scheduler]  [get update]
  leases.coordination.k8s.io                 []                 [kube-scheduler]  [get update]
  pods/status                                []                 []                [patch update]
```

可以看到已经有了相应的权限.

之后重启 kubelet, 相应的 kube-scheduler pod 也会重建.

### 2.2 配置floatingip-config

假设：
k8s节点所属ip网段为：10.177.140.0/22
容器可用ip范围为：10.177.140.40~10.177.140.80
容器ip所属网段为：10.177.140.0/22
容器的网关ip为：10.177.143.254
vlan的id为：1200 (可选)

> 注：这些网络信息，实际通常需要网络组同事帮忙分配确定

以ConfigMap的方式配置，这里创建 `floatingip-config.yaml` 配置文件，内容如下：

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: floatingip-config
  namespace: kube-system
data:
  floatingips: '[{"nodeSubnets":["10.177.140.0/22"],"ips":["10.177.140.40~10.177.140.80"],"subnet":"10.177.140.0/22","gateway":"10.177.143.254"}]'
```

说明：

- routableSubnet：指定kubelet节点所在网段
- ips：指定为容器ip分配的地址范围
- subnet：容器ip的网段
- gateway：容器地址分配的网关
- vlan：是用来指定容器ip的vlan id，当容器ip和节点ip不属于同一个vlan时需要配置（id为数值类型，写的时候不要带引号）

IP 回收策略配置:

- annotations配置：
  - `k8s.v1.cni.cncf.io/networks: "galaxy-k8s-vlan"` ：指明使用的网络类型为 `galaxy-k8s-vlan`
  - `k8s.v1.cni.galaxy.io/release-policy: "never"` ：指明ip的释放策略，有 `never` 和 `immutable` 两种
    - 如果`release-policy`未指定, pod删除后释放IP。
    - `immutable`: 仅在删除 deployment statefulset 等资源或缩容时释放IP, 如果原Node变为NotReady的情况下,pod漂到新节点上，它将获得先前的IP,IP 不变。
    - `never`: 只要 deployment statefulset 等资源名不变, 即使删除资源再次重新创建 IP 也保持不变 .

### 2.3 IP 池个数限制

默认情况下, Galaxy-ipam 是不限制 deployment 或者 statefulset 资源使用 IP 个数的, 但是为了保证升级过程中IP不变可以限制 IP 池.

```yaml
apiVersion: galaxy.k8s.io/v1alpha1
kind: Pool
metadata:
  name: example-pool
size: 4
```

## 部署

前面说明中已经给出了如何配置, 部署就很简单, 和部署普通的应用没有差异.

```bash
# kube-scheduler 配置, 修改 galaxy.json 配置
kubectl apply -f galaxy.yaml
# kube-scheduler 配置
kubectl apply -f scheduler-policy.yaml
kubectl apply -f clusterrole-kube-scheduler.yaml
# 所有 master 节点执行, 一定要等上面的 galaxy daemonSet 启动完成后再执行
sed -i '/--v=2/i\    - --policy-configmap=scheduler-policy' /etc/kubernetes/manifests/kube-scheduler.yaml
systemctl restart kubelet
# 二进制安装
sed -i '/--v=2/i\  --policy-configmap=scheduler-policy' /lib/systemd/system/kube-scheduler.service
systemctl daemon-reload && systemctl restart kube-scheduler.service
# 根据实际情况配置浮动 IP
kubectl apply -f floatingip-config.yaml
kubectl apply -f galaxy-ipam.yaml
```

排错: 查看相应的组件日志

## 测试

- annotations配置：
  - `k8s.v1.cni.cncf.io/networks: "galaxy-k8s-vlan"` ：指明使用的网络类型为 `galaxy-k8s-vlan`
  - `k8s.v1.cni.galaxy.io/release-policy: "never"` ：指明ip的释放策略，有 `never` 和 `immutable` 两种
    - 如果`release-policy`未指定, pod删除后释放IP。
    - `immutable`: 仅在删除 deployment statefulset 等资源或缩容时释放IP, 如果原Node变为NotReady的情况下,pod漂到新节点上，它将获得先前的IP,IP 不变。
    - `never`: 只要 deployment statefulset 等资源名不变, 即使删除资源再次重新创建 IP 也保持不变 .

- resources配置：
  - `requests` 和 `limits` 属性都要添加 `tke.cloud.tencent.com/eni-ip: "1"`
  - 不配置的话，会报如下错误： `fail to establish network map[]:neither ipInfo from cni args nor ipam type from netconf`

另外, 设置为 nerver 的时候, 滚动策略一定要做相应的修改, 否则 IP 不释放, 更新 pod 时始终 pending.

![测试](https://tva1.sinaimg.cn/large/008eGmZEgy1gmryso6puvj31uz0u07ik.jpg)

```yaml
  strategy:
    type: Recreate
```
