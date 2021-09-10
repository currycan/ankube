# 系统资源预留

[Kubernetes 资源预留配置 - 云+社区 - 腾讯云](https://cloud.tencent.com/developer/article/1697043) 这篇文章分析得很到位了，以下是我实践的一些总结。

- 1.21 以上版本配置**系统资源**预留（system-reserved）会报错，问题未知！！！
- 系统资源预留过小会报错：unable to set memory limit to 134217728 (current usage: 292134912, peak usage: 660271104)"
  - 配置系统资源一定要合理，预留太小了即使是 kubelet 组件起来了，管理 pod 生命周期也会异常慢
  - 一般做内存的限制就可以了，system-reserved=memory=300Mi kube-reserved=memory=400Mi
- 测试使用的小资源节点，最好不要限制资源使用，让系统自己去分配更好！！
- 之前配置过 reserve 资源的，如果需要调整会导致 kublet 启动失败，需要先删除所有 reserve 配置，重启主机，待启动成果后再做修改！！

查看资源限制：

```bash
cat /sys/fs/cgroup/memory/kubelet.slice/memory.limit_in_bytes
cat /sys/fs/cgroup/memory/system.slice/memory.limit_in_bytes
```

centos 会报错缺少路径，手动创建就好了！

```bash
mkdir -p /sys/fs/cgroup/cpuset/system.slice
mkdir -p /sys/fs/cgroup/hugetlb/system.slice
mkdir -p /sys/fs/cgroup/systemd/system.slice
mkdir -p /sys/fs/cgroup/memory/system.slice
mkdir -p /sys/fs/cgroup/pids/system.slice
mkdir -p /sys/fs/cgroup/cpu,cpuacct/system.slice
mkdir -p /sys/fs/cgroup/cpu,cpuacct/system.slice
```
