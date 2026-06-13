#!/usr/bin/env bash
# 不依赖 docker-compose，仅用 docker build / docker run（适合无法下载 compose 的服务器）
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_DIR="$(cd "${DEPLOY_DIR}/.." && pwd)"

cd "${DEPLOY_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未找到 docker"
  exit 1
fi

if [[ ! -f .env ]]; then
  echo "错误: 未找到 deploy/.env，请先 cp .env.example .env 并编辑"
  exit 1
fi

# shellcheck disable=SC1091
source .env

if [[ -z "${JWT_SECRET:-}" || "${JWT_SECRET}" == change-me* ]]; then
  echo "错误: 请设置 JWT_SECRET"
  exit 1
fi

if [[ -z "${MYSQL_PASSWORD:-}" || "${MYSQL_PASSWORD}" == change-me* ]]; then
  echo "错误: 请设置 MYSQL_PASSWORD"
  exit 1
fi

API_PORT="${API_PORT:-9091}"
MYSQL_HOST="${MYSQL_HOST:-host.docker.internal}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-easytrans}"
MYSQL_USERNAME="${MYSQL_USERNAME:-root}"
DATASOURCE_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai"

IMAGE_NAME="${IMAGE_NAME:-easytrans-api:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-easytrans-api}"

echo "==> 构建镜像 ${IMAGE_NAME} ..."
docker build -t "${IMAGE_NAME}" -f "${DEPLOY_DIR}/Dockerfile" "${JAVA_DIR}"

echo "==> 停止旧容器（若存在）..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

RUN_ARGS=(
  -d
  --name "${CONTAINER_NAME}"
  --restart unless-stopped
  -p "${API_PORT}:9091"
  -e "SPRING_PROFILES_ACTIVE=prod"
  -e "TZ=Asia/Shanghai"
  -e "JWT_SECRET=${JWT_SECRET}"
  -e "MYSQL_USERNAME=${MYSQL_USERNAME}"
  -e "MYSQL_PASSWORD=${MYSQL_PASSWORD}"
  -e "SPRING_DATASOURCE_URL=${DATASOURCE_URL}"
  -e "DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY:-}"
  -e "MIMO_API_KEY=${MIMO_API_KEY:-}"
  -e "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}"
  -e "APP_CORS_ALLOWED_ORIGINS=${APP_CORS_ALLOWED_ORIGINS:-*}"
)

# 连接宿主机 MySQL（host.docker.internal）
if [[ "${MYSQL_HOST}" == "host.docker.internal" ]]; then
  if docker run --help 2>&1 | grep -q host-gateway; then
    RUN_ARGS+=(--add-host=host.docker.internal:host-gateway)
  else
    # 旧版 Docker：用默认网桥网关
    RUN_ARGS+=(--add-host=host.docker.internal:172.17.0.1)
  fi
fi

# 与 MySQL 同 Docker 网络（可选）
if [[ -n "${MYSQL_DOCKER_NETWORK:-}" ]]; then
  RUN_ARGS+=(--network "${MYSQL_DOCKER_NETWORK}")
fi

echo "==> 启动容器 ${CONTAINER_NAME} ..."
docker run "${RUN_ARGS[@]}" "${IMAGE_NAME}"

echo
echo "==> 等待服务就绪 ..."
for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT}/api/v1/health" >/dev/null 2>&1; then
    echo "成功: http://127.0.0.1:${API_PORT}/api/v1/health"
    docker ps --filter "name=${CONTAINER_NAME}"
    exit 0
  fi
  sleep 2
done

echo "启动超时，查看日志: docker logs -f ${CONTAINER_NAME}"
exit 1
