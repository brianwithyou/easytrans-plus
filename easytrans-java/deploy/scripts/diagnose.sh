#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-easytrans-api}"
API_PORT="${API_PORT:-9091}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# shellcheck disable=SC1091
[[ -f .env ]] && source .env

echo "=== 容器状态 ==="
docker ps -a --filter "name=${CONTAINER_NAME}"

echo
echo "=== 最近日志 ==="
docker logs "${CONTAINER_NAME}" --tail 100 2>&1 || true

echo
echo "=== 健康检查 ==="
curl -v "http://127.0.0.1:${API_PORT}/api/v1/health" 2>&1 || true

echo
echo "=== 宿主机 MySQL ==="
if command -v mysql >/dev/null 2>&1 && [[ -n "${MYSQL_PASSWORD:-}" ]]; then
  mysql -h 127.0.0.1 -P "${MYSQL_PORT:-3306}" -u "${MYSQL_USERNAME:-root}" -p"${MYSQL_PASSWORD}" \
    -e "SHOW DATABASES LIKE 'easytrans';" 2>&1 || echo "MySQL 连接失败"
else
  echo "未安装 mysql 客户端或未配置 MYSQL_PASSWORD"
fi
