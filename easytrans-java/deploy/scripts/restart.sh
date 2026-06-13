#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=compose.sh
source "${DEPLOY_DIR}/scripts/compose.sh" 2>/dev/null || true

cd "${DEPLOY_DIR}"
CONTAINER_NAME="${CONTAINER_NAME:-easytrans-api}"
API_PORT="${API_PORT:-9091}"

# shellcheck disable=SC1091
[[ -f .env ]] && source .env

restart_compose() {
  COMPOSE_FILES=(-f docker-compose.yml)
  [[ -n "${MYSQL_DOCKER_NETWORK:-}" ]] && COMPOSE_FILES+=(-f docker-compose.mysql-network.yml)
  compose "${COMPOSE_FILES[@]}" restart api
}

if docker ps -a --format '{{.Names}}' | grep -qx "${CONTAINER_NAME}"; then
  echo "==> 重启容器 ${CONTAINER_NAME} ..."
  docker restart "${CONTAINER_NAME}"
elif command -v compose >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
  echo "==> 通过 compose 重启 api ..."
  restart_compose
else
  echo "错误: 未找到容器 ${CONTAINER_NAME}"
  exit 1
fi

echo "==> 等待就绪 ..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT}/api/v1/health" >/dev/null 2>&1; then
    echo "成功: http://127.0.0.1:${API_PORT}/api/v1/health"
    docker ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  sleep 2
done

echo "健康检查超时，查看日志: docker logs ${CONTAINER_NAME} --tail 50"
exit 1
