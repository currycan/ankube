# ansible 安装 kubernetes 高可用集群

> 支持 binary 和 kubeadm 两种方式

## 1. 准备

### 1.1 安装 ansible

- Centos 7:

```bash
curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum install -y ansible
```

- Ubuntu :

``` bash
apt-get update && apt-get install -y ansible
```

安装 ansible 统计任务处理时间插件

```bash
mkdir /etc/ansible/callback_plugins
wget -P /etc/ansible/callback_plugins https://raw.githubusercontent.com/jlafon/ansible-profile/master/callback_plugins/profile_tasks.py
```

### 1.2 配置免密

```bash
# Ed25519 算法, 更安全
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
# 或者传统 RSA 算法
ssh-keygen -t rsa -b 2048 -N '' -f ~/.ssh/id_rsa

ssh-copy-id $IPs #$IPs为所有节点地址包括自身，按照提示输入 yes 和 root 密码
```

### 1.3 时间校准(如果时间误差比较大)

时间误差大, 会导致ssl认证失败, 从而下载文件失败或者其他奇怪问题.

```bash
# 查看时间
date
# 时间校准
yum -y install ntpdate
ntpdate -u cn.pool.ntp.org
date
hwclock -w
# 如果出现时间不对导致 ssl 认证失败, 重装 ca-certificates:
yum reinstall -y ca-certificates
```

所有节点操作:

```bash
ansible all -a "date"
ansible all -a "yum -y install ntpdate"
ansible all -a "ntpdate -u cn.pool.ntp.org"
ansible all -a "hwclock -w"
```

### 1.4 deploy 节点创建离线文件目录,确保磁盘空间大于 20G

```bash
mkdir -p /k8s_cache
```

#### 1.4.1 挂载数据盘(可选)

安装 lvm

```bash
# Centos
yum -y install lvm2*
# Ubuntu
apt-get -y install lvm2*
```

参考: [初识LVM及ECS上LVM分区扩容-阿里云开发者社区](https://developer.aliyun.com/article/572204)

查看磁盘信息

```bash
$ lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda               8:0    0   40G  0 disk
├─sda1            8:1    0    1G  0 part /boot
└─sda2            8:2    0   39G  0 part
  ├─centos-root 253:0    0   35G  0 lvm  /
  └─centos-swap 253:1    0    4G  0 lvm  [SWAP]
sdb               8:16   0  100G  0 disk
sr0              11:0    1 1024M  0 rom
```

sdb 是一块新的数据盘, 创建一个 LVM 分区. fdisk的参数（n/p/1/回车/回车/t/8e/w）
注：8e代表是lvm的分区

```bash
DISK1=sdb
# 创建和管理LVM
fdisk /dev/${DISK1}
> n/p/1/回车/回车/t/8e/w
# 创建 PV
pvcreate /dev/${DISK1}1
# 创建 VG
vgcreate k8s /dev/${DISK1}1
# 创建 LV
lvcreate -L 10G -n download k8s
# lvcreate -l 100%VG -n download k8s
lvcreate -L 10G -n data k8s
# 格式化 LVM 分区
mkfs.xfs /dev/k8s/download
mkfs.xfs /dev/k8s/data
# 挂载 LVM 分区(/k8s_cache)
mkdir -p /k8s_cache
mkdir -p /var/lib/docker
mount /dev/k8s/download /k8s_cache/
mount /dev/k8s/data /var/lib/docker
echo "/dev/k8s/download    /k8s_cache     xfs    defaults        0 0" >>/etc/fstab
echo "/dev/k8s/data   /var/lib/docker    xfs    defaults        0 0" >>/etc/fstab
```

删除LVM

```bash
# 查看lvm
lvs
# 删除 lvm
lvremove /dev/k8s/data
```

## 2. 配置

配置文件在 group_vars 和 hosts 中都有体现，核心参数是在 hosts 中进行调整。各组件版本在[version.yml](group_vars/all/version.yml)中，另外关于集群的安装方式和证书的创建方式，在[certs.yml](group_vars/all/certs.yml)中:

```yaml
## 设定安装方式：二进制安装或者kubeadm安装
binary_way:
  enable: false
  ## 设定证书生成方式：cfssl或者openssl
  cfssl_cert: false
  openssl_cert: true
kubeadm_way:
  enable: true
  ## 设定证书是自定义签发或者kubeadm签发, 使用kubeadm方式搭建集群暂不支持cfssl生成的pem证书
  kubeadm_cert: true
```

举例来说，若是需要用二进制安装方式，但是用 kubeadm 创建证书，则：
binary_way.enable=true
kubeadm_way.enable=false
kubeadm_way.kubeadm_cert=true

另外, 关于 storage class 默认选择的是: nfs, 且安装在 master3 节点, 根据需要可以调整.

安装 nfs server:

```bash
yum install nfs-utils rpcbind -y
systemctl enable --now rpcbind.service
systemctl enable --now nfs.service
mkdir -p /nfs/data
chown nfsnobody:nfsnobody /nfs/data
echo "/nfs/data 10.10.10.0/24(rw,sync,no_root_squash)">>/etc/exports
echo "/nfs/data 127.0.0.1(rw,sync,no_root_squash)">>/etc/exports
exportfs -rv
showmount -e localhost
```

- base.yml 修改:
  - 各组件版本, 根据需要修改
  - pod cidr 和 service cidr, 可选择默认不修改
  - vip_address/metallb 地址池/ingress 地址/nfs_server地址, **必须修改**
  - helm 版本, 默认安装 helm3

- global.yml 修改
  - container_runtime, 支持 docker 和 containerd, 默认: docker
  - nfs_server_path 路径, 默认: /nfs/data
  - docker/kubectl/helm 客户端普通用户操作集群权限, 如: devops 用户

如需要修改其他内容, 请确保了解整个安装过程

## 3. 安装说明

在搭建集群时, 请准备一个集群外的一个单独的 deploy 节点来完成, 例如新建一个 virtualbox 虚拟机作为安装节点,deploy 节点配置 ssh 免密.

### 3.1 下载准备文件

00.x-yml 的 playbook 是准备环境, 具体如下:

- 00.1-parted_disks.yml: 磁盘分区, 给docker 和 kubelet 数据单独的磁盘,同样 etcd 也可以配置单独的数据盘
- 00.2-download.yml: 自行下载集群依赖的二进制文件和离线镜像(可能比较耗时,最好有代理能够下载国外文件)
- 00.3-kernel.yml: 安装需要的 Linux 内核
- 00.4-python3.yml: 安装 Python3

### 3.2 集群搭建

cluster_setup.yml 支持一键安装,当然也可以根据实际需要一步步安装.

- 01.initialize.yml: 基础环境校验，并进行初始化依赖安装，参数优化
- 02.container.yml: 安装容器运行时引擎（docker/containderd）,并加载离线镜像
- 03.certs.yml: 创建依赖的证书，支持三种方式: kubeadm 、openssl 和 cfssl，证书有效期 10 年
- 04.etcd.yml: 安装 etcd 集群，二进制安装，保证性能
- 05.kubernetes.yml: 安装 kubernetes 集群，支持二进制和 kubeadm 安装
- 06.network.yml: 安装网络插件
- ansible-playbook 07.helm.yml: 安装 helm
- ansible-playbook 08.addons.yml: 安装一些常见插件，比如: ingress、metallb

``` bash
# 分步安装, 核心组件
ansible-playbook 01.initialize.yml
ansible-playbook 02.container.yml
ansible-playbook 03.certs.yml
ansible-playbook 04.etcd.yml
ansible-playbook 05.kubernetes.yml
ansible-playbook 06.network.yml

# 其他组件, 如果不需要安装 非核心组件,以下无需执行
ansible-playbook 07.helm.yml
ansible-playbook 08.addons.yml

# 一键安装, 默认注释了非核心组件安装
ansible-playbook cluster_setup.yml
```

## 4. 维护

支持集群一键备份和迁移

## 5. 安装异常处理

### 5.1 kubeadm init 失败

排查问题后, 如 `kubeadm-config.yaml` 配置参数问题修复后, 只需要清理部分文件后再运行一遍, 不要 `kubeadm reset` 会删除 证书文件!!

在第一个master 节点上运行:

```bash
rm -rf /etc/kubernetes/manifests/
systemctl stop kubelet.service
docker ps -aq | xargs docker rm -f
```

在 deploy 节点运行

```bash
ansible-playbook  04.kubernetes.yml
```

如需要调试安装,可以直接运行:

```bash
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
```
