#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SQL_FILE="${DEPLOY_DIR}/../sql/01_schema.sql"

cd "${DEPLOY_DIR}"

if [[ ! -f .env ]]; then
  echo "错误: 未找到 deploy/.env"
  exit 1
fi

# shellcheck disable=SC1091
source .env

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-easytrans}"
MYSQL_USERNAME="${MYSQL_USERNAME:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:?请在 .env 中设置 MYSQL_PASSWORD}"

if [[ ! -f "${SQL_FILE}" ]]; then
  echo "错误: 未找到 ${SQL_FILE}"
  exit 1
fi

echo "==> 初始化数据库 ${MYSQL_DATABASE} @ ${MYSQL_HOST}:${MYSQL_PORT}"

if command -v mysql >/dev/null 2>&1; then
  mysql -h "${MYSQL_HOST}" -P "${MYSQL_PORT}" -u "${MYSQL_USERNAME}" -p"${MYSQL_PASSWORD}" < "${SQL_FILE}"
  echo "完成。"
  exit 0
fi

if docker ps --format '{{.Names}}' | grep -q .; then
  echo "本机未安装 mysql 客户端，尝试通过 MySQL 容器执行 ..."
  echo "请手动执行其一："
  echo
  echo "  mysql -h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USERNAME} -p < ${SQL_FILE}"
  echo
  echo "或进入你的 MySQL 容器："
  echo "  docker exec -i <mysql容器名> mysql -u${MYSQL_USERNAME} -p${MYSQL_PASSWORD} < ${SQL_FILE}"
  exit 1
fi

echo "错误: 未找到 mysql 命令。请安装 mysql 客户端或手动导入 ${SQL_FILE}"
exit 1
