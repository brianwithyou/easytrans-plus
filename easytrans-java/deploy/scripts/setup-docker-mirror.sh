#!/usr/bin/env bash
# 配置 Docker 国内镜像加速（腾讯云机器优先用腾讯云镜像）
set -euo pipefail

MIRROR="${1:-tencent}"

case "${MIRROR}" in
  tencent)
    URL="https://mirror.ccs.tencentyun.com"
    ;;
  aliyun)
    echo "请先到 https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors 获取你的专属加速地址"
    echo "用法: $0 aliyun https://xxxx.mirror.aliyuncs.com"
    exit 1
    ;;
  *)
    URL="${MIRROR}"
    ;;
esac

mkdir -p /etc/docker
if [[ -f /etc/docker/daemon.json ]]; then
  cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)"
fi

cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["${URL}"]
}
EOF

systemctl daemon-reload
systemctl restart docker

echo "已配置镜像加速: ${URL}"
echo "测试拉取: docker pull eclipse-temurin:25-jre-jammy"
