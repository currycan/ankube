rm -rf /etc/kubernetes/manifests/
systemctl stop kubelet.service
docker ps -aq | xargs docker rm -f
find /var/lib/kubelet | xargs -n 1 findmnt -n -t tmpfs -o TARGET -T | uniq | xargs -r umount -v
rm -rf /var/lib/kubelet/
rm -rf /var/lib/kubelet/*_manager_state
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml

# 升级
kubeadm upgrade apply --config kubeadm-config.yaml --ignore-preflight-errors=all
kubeadm upgrade apply --config kubeadm-config.yaml --ignore-preflight-errors=CoreDNSUnsupportedPlugins --ignore-preflight-errors=CoreDNSMigration

# join
systemctl stop kubelet.service
rm -rf /etc/kubernetes/manifests/
docker ps -aq | xargs docker rm -f
rm -rf /var/lib/kubelet/
rm -rf /var/lib/kubelet/*_manager_state
rm -f /etc/kubernetes/kubelet.conf
