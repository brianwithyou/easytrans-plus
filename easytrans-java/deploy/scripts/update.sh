#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${DEPLOY_DIR}"

if [[ ! -f .env ]]; then
  echo "错误: 未找到 deploy/.env"
  exit 1
fi

# shellcheck disable=SC1091
source .env

echo "==> 停止服务 ..."
docker compose down

echo "==> 拉取基础镜像并重新构建 ..."
docker compose build --pull

echo "==> 启动服务 ..."
docker compose up -d

echo "==> 完成。健康检查: curl http://127.0.0.1:${API_PORT:-9091}/api/v1/health"
