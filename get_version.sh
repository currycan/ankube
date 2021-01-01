#!/bin/bash

set -ex

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Blue_background_prefix="\033[44;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"

: ${ROLES_DIR:=$(pwd)}

echo -e "${Blue_background_prefix}>>>>Please wait a moment to get the binaries version..${Font_color_suffix}"
declare -a binaries_url=(
    # [k8s_url]=https://github.com/kubernetes/kubernetes/tags
    [kube_url]=https://dl.k8s.io/release/stable.txt
    [docker_url]=https://download.docker.com/linux/static/stable/x86_64
    [containerd_url]=https://github.com/containerd/containerd/tags
    [docker_compose_url]=https://github.com/docker/compose/tags
    [cfssl_url]=https://github.com/cloudflare/cfssl/tags
    [etcd_url]=https://github.com/etcd-io/etcd/tags
    [cni_url]=https://github.com/containernetworking/plugins/tags
    [flanneld_url]=https://github.com/coreos/flannel/tags
    [cilium_url]=https://github.com/cilium/cilium/tags
    [kubeovn_url]=https://github.com/alauda/kube-ovn/tags
    [calico_url]=https://github.com/projectcalico/calico/tags
    [coredns_url]=https://github.com/coredns/coredns/tags
    [helm_url]=https://github.com//helm/helm/tags
    [helmfile_url]=https://github.com/roboll/helmfile/tags
    [kustomize_url]=https://github.com/kubernetes-sigs/kustomize/tags
    [krew_url]=https://github.com/kubernetes-sigs/krew/tags
    [kubectl_debug_url]=https://github.com/aylei/kubectl-debug/tags
    [k9s_url]=https://github.com/derailed/k9s/tags
    [argocd_url]=https://github.com/argoproj/argo-cd/tags
    [vela_url]=https://github.com/oam-dev/kubevela/tags
    [tektoncd_url]=https://github.com/tektoncd/cli/tags
    [istio_url]=https://github.com/istio/istio/tags
)
for binary_url in ${!binaries_url[@]}; do
    binary=$(echo $binary_url | awk -F'_url' '{print $1}')
    if [[ ${binary} == "kube" ]]; then
        export "${binary}_version=$(wget -qO- ${binaries_url[$binary_url]})"
    elif [[ ${binary} == "docker" ]]; then
        export "${binary}_version=$(wget -qO- ${binaries_url[$binary_url]} | grep -e docker | tail -n 1 | cut -d">" -f1 | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*")"
    elif [[ ${binary} == "cfssl" ]]; then
        export "${binary}_version=R$(wget -qO- ${binaries_url[$binary_url]} | grep -e "CFSSL" | grep -oP "[0-9]\d*\.[0-9]\d*" | head -n 1)"
    else
        export "${binary}_version=$(wget -qO- ${binaries_url[$binary_url]} | grep -e "releases/tag/" | grep -e "muted-link" | grep -v "rc" | grep -v "alpha" | grep -v "beta" | grep -oP "[a-zA-Z]*[0-9]\d*\.[0-9]\d*\.[0-9]\d*" | head -n 1)"
    fi
done
echo -e "${Green_font_prefix}++++++++++++++++++++++++++++++++++${Font_color_suffix}"
echo -e "${Green_font_prefix}kube_version=$kube_version${Font_color_suffix}"
echo -e "${Green_font_prefix}docker_version=$docker_version${Font_color_suffix}"
echo -e "${Green_font_prefix}containerd_version=$containerd_version${Font_color_suffix}"
echo -e "${Green_font_prefix}docker_compose_version=$docker_compose_version${Font_color_suffix}"
echo -e "${Green_font_prefix}cfssl_version=$cfssl_version${Font_color_suffix}"
echo -e "${Green_font_prefix}etcd_version=$etcd_version${Font_color_suffix}"
echo -e "${Green_font_prefix}cni_version=$cni_version${Font_color_suffix}"
echo -e "${Green_font_prefix}flanneld_version=$flanneld_version${Font_color_suffix}"
echo -e "${Green_font_prefix}calico_version=$calico_version${Font_color_suffix}"
echo -e "${Green_font_prefix}coredns_version=$coredns_version${Font_color_suffix}"
echo -e "${Green_font_prefix}helm_version=$helm_version${Font_color_suffix}"
echo -e "${Green_font_prefix}harbor_version=$harbor_version${Font_color_suffix}"
echo -e "${Green_font_prefix}++++++++++++++++++++++++++++++++++${Font_color_suffix}"

https://github.com/kubernetes-sigs/cluster-proportional-autoscaler/tags
