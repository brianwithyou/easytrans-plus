#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=compose.sh
source "${DEPLOY_DIR}/scripts/compose.sh"

cd "${DEPLOY_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未找到 docker，请先安装 Docker。"
  exit 1
fi

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "已生成 deploy/.env，请先编辑其中的 MySQL、JWT、LLM Key，然后重新运行本脚本。"
  exit 1
fi

# shellcheck disable=SC1091
source .env

if [[ -z "${JWT_SECRET:-}" || "${JWT_SECRET}" == change-me* ]]; then
  echo "错误: 请在 deploy/.env 中设置 JWT_SECRET（至少 32 位随机字符串）。"
  exit 1
fi

if [[ -z "${MYSQL_PASSWORD:-}" || "${MYSQL_PASSWORD}" == change-me* ]]; then
  echo "错误: 请在 deploy/.env 中设置 MYSQL_PASSWORD（你的 MySQL 8 密码）。"
  exit 1
fi

if [[ -z "${DASHSCOPE_API_KEY:-}${MIMO_API_KEY:-}${DEEPSEEK_API_KEY:-}" ]]; then
  echo "警告: 未配置任何 LLM API Key，翻译接口将无法工作。"
fi

COMPOSE_FILES=(-f docker-compose.yml)
if [[ -n "${MYSQL_DOCKER_NETWORK:-}" ]]; then
  COMPOSE_FILES+=(-f docker-compose.mysql-network.yml)
  echo "==> 使用外部 Docker 网络: ${MYSQL_DOCKER_NETWORK}"
  echo "    MYSQL_HOST=${MYSQL_HOST:-?}"
fi

echo "==> 构建并启动 EasyTrans Plus API ..."
compose "${COMPOSE_FILES[@]}" up -d --build

echo
echo "==> 等待健康检查 ..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT:-9091}/api/v1/health" >/dev/null 2>&1; then
    echo "服务已就绪: http://127.0.0.1:${API_PORT:-9091}/api/v1/health"
    compose "${COMPOSE_FILES[@]}" ps
    exit 0
  fi
  sleep 2
done

echo "服务启动超时，请查看日志:"
echo "  cd ${DEPLOY_DIR} && compose ${COMPOSE_FILES[*]} logs -f api"
exit 1
