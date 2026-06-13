#!/usr/bin/env bash
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=compose.sh
source "${DEPLOY_DIR}/scripts/compose.sh"

cd "${DEPLOY_DIR}"

# shellcheck disable=SC1091
source .env 2>/dev/null || true

COMPOSE_FILES=(-f docker-compose.yml)
if [[ -n "${MYSQL_DOCKER_NETWORK:-}" ]]; then
  COMPOSE_FILES+=(-f docker-compose.mysql-network.yml)
fi

compose "${COMPOSE_FILES[@]}" logs -f --tail=200 api
