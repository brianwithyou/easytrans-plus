#!/usr/bin/env bash
# 服务器一站式：构建 JAR + 部署 API（推荐在服务器上使用）
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"${DEPLOY_DIR}/scripts/build-jar-on-server.sh"
"${DEPLOY_DIR}/scripts/deploy-prebuilt.sh"
