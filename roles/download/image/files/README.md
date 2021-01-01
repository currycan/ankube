# 使用说明

- goinstall.sh 用于安装golang

- download-frozen-image-v2.sh 依赖jq，需要先安装jq

```text
❯ bash download-frozen-image-v2.sh
usage: download-frozen-image-v2.sh dir image[:tag][@digest] ...
       download-frozen-image-v2.sh /tmp/old-hello-world hello-world:latest@sha256:8be990ef2aeb16dbcb9271ddfe2610fa6658d13f6dfb8bc72074cc1ca36966a7
```

下载后加载镜像

```text
tar -cC dir . | docker load
# 也可以
tar -cC 'dir' . > image-name.tar
```
