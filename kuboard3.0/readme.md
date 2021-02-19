# 说明

## 1. 环境准备

kuboard 支持多种单点登陆认证，此文档主要介绍 ldap 认证方式。

在使用之前需要安装配置好 ldap

测试ldap账户信息如下：

group： demo

account：test@demo.com

password：123456

[kuboard 官网链接](https://kuboard.cn/install/v3/install-ldap.html#%E5%87%86%E5%A4%87-ldap)

## 2. kuboard3.0 安装

通过 docker-compose 的形式安装，安装的参数通过 .env 文件体现。

要求 docker-compose 版本大于 1.27

注意：一定要配置.env文件！！

```bash
docker-compose up -d
docker-compose ps
```

## 3. kuboard 配置

用户名： test@demo.com

密 码： 123456

登陆后，根据界面提示添加集群。

## 3.1 添加集群

### 3.1.1 步骤一:

![步骤一](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsuaj2juqj32rs0rm79c.jpg)

### 3.1.2 步骤二:

在要添加的集群任意节点（配置好kubeconfig）上执行安装命令，完成后勾选`我已经执行了导入命令`。

![步骤二](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsue2bifxj32230u0dm6.jpg)

根据提示检查 agent 是否安装成功

![步骤二](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsuid13njj31vc0saah4.jpg)

安装成功后，界面上会有绿色字体的提示`导入成功`

### 3.1.3 步骤三:

点击 `单点登陆`，进行单点登陆激活，同样根据提示完成即可！注意，每个master节点都需要执行。

![步骤三](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsvuazosyj30u02jb4qq.jpg)

根据界面提示配置证书

配置 kube-apiserver oidc 参数：

```bash
# kubeadm 安装
KUBOARD_DOMAIN="kuboard.example.com"
sed -i "/- --profiling=false/i\    - --oidc-issuer-url=https://${KUBOARD_DOMAIN}:443/sso" /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-client-id=kuboard-sso' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-username-claim=preferred_username' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-username-prefix=-' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-groups-claim=groups' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-groups-prefix=' /etc/kubernetes/manifests/kube-apiserver.yaml
sed -i '/- --profiling=false/i\    - --oidc-ca-file=/etc/ssl/certs/kuboard.crt' /etc/kubernetes/manifests/kube-apiserver.yaml
systemctl restart kubelet.service
# 二进制安装
KUBOARD_DOMAIN="kuboard.example.com"
sed -i "/--profiling=false/i\  --oidc-issuer-url=https://${KUBOARD_DOMAIN}:443/sso \\\\" /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-client-id=kuboard-sso \\' /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-username-claim=preferred_username \\' /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-username-prefix=- \\' /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-groups-claim=groups \\' /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-groups-prefix= \\' /lib/systemd/system/kube-apiserver.service
sed -i '/--profiling=false/i\  --oidc-ca-file=/etc/ssl/certs/kuboard.crt \\' /lib/systemd/system/kube-apiserver.service
systemctl daemon-reload && systemctl restart kube-apiserver.service
```

配置完成后，等待kube-apiserver启动，点击刷新出现如下图所示界面即可。

![步骤三](https://tva1.sinaimg.cn/large/008eGmZEgy1gnswoenhfvj31yw0t0dn7.jpg)

**注意：后续的名称空间布局，现有测试版本点击会报错，无需关注，做完上一步即可。直接返回到主界面。**

## 3.2 集群管理

添加集群后集群所在的namespace都无法访问，此时需要配置rbac来实现访问控制。

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnswxhpbnmj31yl0u0ak3.jpg)

rbac控制的工具有很多，通过此安装脚本安装集群的时候已经内置了多个clusterrole,具体如下：

```bash
[root@k8s-master-01 ~]# kubectl get clusterrole | grep cs:
cs:admin                                                               2021-02-02T03:40:06Z
cs:ns:dev                                                              2021-02-02T03:40:06Z
cs:ops                                                                 2021-02-02T03:40:06Z
```

这里，使用集群内置的kuboard 2.0 进行角色绑定实现访问控制：

登陆2.0控制台：设置 --> 权限管理 --> group（这里以创建group权限为例，同样也可以创建user权限）

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsx82qi8cj34mk0jejwa.jpg)

在测试的时候创建的是 demo 组，因此这里也是为 demo 组授权

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsxc73qu3j30w20ku772.jpg)

这里需要选择要授权访问的namespace，然后选择 RoleBinding 或者 ClusterRoleBinding（集群级别资源，控制力度粗），从而进行访问控制

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsxfj645uj31x50u0arx.jpg)

这里以 RoleBinding 为例：

选择 docker-2048 namespace, clusterrole 选择 cs:ops，然后保存。

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsxyjeqqgj327z0u0wod.jpg)

访问控制创建完成后，再次进入集群管理界面，已经有了 docker-2048 的访问权限。（**访问权限发生变化后，需要退出重新登陆后生效！！**）

![集群管理](https://tva1.sinaimg.cn/large/008eGmZEgy1gnsy2bf05zj31dd0u0gtg.jpg)

## 通过 RBAC 权限管理集群

- 创建用户
  - LDAP 创建组和用户
  - k8s 集群创建组和用户
- 创建role/clusterrole
- 创建 rolebinding/clusterrolebinding

参考 github 项目

- [rbac-tool](https://github.com/alcideio/rbac-tool)
- [adduser](https://github.com/brendandburns/kubernetes-adduser)
- [permission-manager](https://github.com/sighupio/permission-manager)
- [kubeconfig-generator](https://github.com/kairen/kubeconfig-generator)
- [oidc](https://www.dazhuanlan.com/2019/12/27/5e057a21760f1/)
