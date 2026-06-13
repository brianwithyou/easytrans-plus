#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_DIR="${ROOT_DIR}/deploy"

cd "${DEPLOY_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未找到 docker，请先安装 Docker。"
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "错误: 未找到 docker compose 插件。"
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "已生成 deploy/.env，请先编辑其中的密码和 API Key，然后重新运行本脚本。"
  exit 1
fi

# shellcheck disable=SC1091
source .env

if [[ -z "${JWT_SECRET:-}" || "${JWT_SECRET}" == change-me* ]]; then
  echo "错误: 请在 deploy/.env 中设置 JWT_SECRET（至少 32 位随机字符串）。"
  exit 1
fi

if [[ -z "${MYSQL_ROOT_PASSWORD:-}" || "${MYSQL_ROOT_PASSWORD}" == change-me* ]]; then
  echo "错误: 请在 deploy/.env 中设置 MYSQL_ROOT_PASSWORD。"
  exit 1
fi

if [[ -z "${DASHSCOPE_API_KEY:-}${MIMO_API_KEY:-}${DEEPSEEK_API_KEY:-}" ]]; then
  echo "警告: 未配置任何 LLM API Key，翻译接口将无法工作。"
fi

echo "==> 构建并启动 EasyTrans Plus API ..."
docker compose up -d --build

echo
echo "==> 等待健康检查 ..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT:-9091}/api/v1/health" >/dev/null 2>&1; then
    echo "服务已就绪: http://127.0.0.1:${API_PORT:-9091}/api/v1/health"
    docker compose ps
    exit 0
  fi
  sleep 2
done

echo "服务启动超时，请查看日志: docker compose -f ${DEPLOY_DIR}/docker-compose.yml logs -f api"
exit 1
