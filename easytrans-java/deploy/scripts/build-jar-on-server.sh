#!/usr/bin/env bash
# 在服务器上用 Docker 跑 Maven 构建 JAR（无需本机安装 JDK/Maven，无需 Mac 上传）
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JAVA_DIR="$(cd "${DEPLOY_DIR}/.." && pwd)"

cd "${DEPLOY_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "错误: 未找到 docker"
  exit 1
fi

MAVEN_IMAGE="${MAVEN_IMAGE:-maven:3.9.16-eclipse-temurin-25}"
SETTINGS_FILE="${DEPLOY_DIR}/maven/settings.xml"
MAVEN_CACHE_DIR="${MAVEN_CACHE_DIR:-${DEPLOY_DIR}/.m2/repository}"

mkdir -p "${MAVEN_CACHE_DIR}"

echo "==> 使用镜像 ${MAVEN_IMAGE} 在服务器构建 JAR ..."
echo "    项目目录: ${JAVA_DIR}"
echo "    Maven 依赖缓存: ${MAVEN_CACHE_DIR}"
echo "    Maven 镜像源: 阿里云（deploy/maven/settings.xml）"

docker run --rm \
  -v "${JAVA_DIR}:/workspace" \
  -v "${MAVEN_CACHE_DIR}:/root/.m2/repository" \
  -v "${SETTINGS_FILE}:/root/.m2/settings.xml:ro" \
  -w /workspace \
  "${MAVEN_IMAGE}" \
  mvn -B -DskipTests package

JAR_FILE="$(ls "${JAVA_DIR}"/target/easytrans-java-*.jar 2>/dev/null | head -1 || true)"
if [[ -z "${JAR_FILE}" ]]; then
  echo "错误: 构建完成但未找到 target/easytrans-java-*.jar"
  exit 1
fi

echo "==> 构建成功: ${JAR_FILE}"
ls -lh "${JAR_FILE}"
