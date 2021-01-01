rm -rf /etc/kubernetes/manifests/
systemctl stop kubelet.service
docker ps -aq | xargs docker rm -f
kubeadm init --config /etc/kubernetes/kubeadm-config.yaml

# 升级
kubeadm upgrade apply --config kubeadm-config.yaml --ignore-preflight-errors=all
kubeadm upgrade apply --config kubeadm-config.yaml --ignore-preflight-errors=CoreDNSUnsupportedPlugins --ignore-preflight-errors=CoreDNSMigration

# join
rm -f /etc/kubernetes/kubelet.conf
