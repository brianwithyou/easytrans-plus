#!/usr/bin/env bash
# 使用本机已构建的 JAR 部署（跳过容器内 mvn，适合服务器网络慢）
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_DIR="$(cd "${DEPLOY_DIR}/.." && pwd)"

cd "${DEPLOY_DIR}"

if [[ ! -f .env ]]; then
  echo "错误: 未找到 deploy/.env"
  exit 1
fi

JAR_FILE="$(ls "${JAVA_DIR}"/target/easytrans-java-*.jar 2>/dev/null | head -1 || true)"
if [[ -z "${JAR_FILE}" ]]; then
  echo "错误: 未找到 target/easytrans-java-*.jar"
  echo
  echo "请先在本地（Mac）构建并上传："
  echo "  cd easytrans-java && mvn -DskipTests package"
  echo "  scp target/easytrans-java-*.jar root@服务器:/opt/easytrans-plus/easytrans-java/target/"
  exit 1
fi

# shellcheck disable=SC1091
source .env

API_PORT="${API_PORT:-9091}"
MYSQL_HOST="${MYSQL_HOST:-host.docker.internal}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-easytrans}"
MYSQL_USERNAME="${MYSQL_USERNAME:-root}"
DATASOURCE_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${MYSQL_DATABASE}?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai"
IMAGE_NAME="${IMAGE_NAME:-easytrans-api:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-easytrans-api}"

echo "==> 使用 JAR: ${JAR_FILE}"
echo "==> 构建运行时镜像（JDK 25 JRE，无 mvn 步骤）..."
docker build -t "${IMAGE_NAME}" -f "${DEPLOY_DIR}/Dockerfile.prebuilt" "${JAVA_DIR}"

docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

RUN_ARGS=(
  -d --name "${CONTAINER_NAME}" --restart unless-stopped
  -p "${API_PORT}:9091"
  -e "SPRING_PROFILES_ACTIVE=prod" -e "TZ=Asia/Shanghai"
  -e "JWT_SECRET=${JWT_SECRET}"
  -e "MYSQL_USERNAME=${MYSQL_USERNAME}" -e "MYSQL_PASSWORD=${MYSQL_PASSWORD}"
  -e "SPRING_DATASOURCE_URL=${DATASOURCE_URL}"
  -e "DASHSCOPE_API_KEY=${DASHSCOPE_API_KEY:-}"
  -e "MIMO_API_KEY=${MIMO_API_KEY:-}"
  -e "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}"
  -e "APP_CORS_ALLOWED_ORIGINS=${APP_CORS_ALLOWED_ORIGINS:-*}"
)

if [[ "${MYSQL_HOST}" == "host.docker.internal" ]]; then
  if docker run --help 2>&1 | grep -q host-gateway; then
    RUN_ARGS+=(--add-host=host.docker.internal:host-gateway)
  else
    RUN_ARGS+=(--add-host=host.docker.internal:172.17.0.1)
  fi
fi
[[ -n "${MYSQL_DOCKER_NETWORK:-}" ]] && RUN_ARGS+=(--network "${MYSQL_DOCKER_NETWORK}")

docker run "${RUN_ARGS[@]}" "${IMAGE_NAME}"

for i in {1..30}; do
  if curl -fsS "http://127.0.0.1:${API_PORT}/api/v1/health" >/dev/null 2>&1; then
    echo "成功: http://127.0.0.1:${API_PORT}/api/v1/health"
    exit 0
  fi
  sleep 2
done
echo "启动超时: docker logs -f ${CONTAINER_NAME}"
exit 1
