#!/usr/bin/env bash

# 兼容 docker compose (v2 插件) 与 docker-compose (v1 独立命令)

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    echo "错误: 未找到 docker compose。" >&2
    echo "  CentOS 可执行: yum install -y docker-compose-plugin" >&2
    echo "  或: curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose" >&2
    exit 1
  fi
}
