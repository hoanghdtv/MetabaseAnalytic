#!/usr/bin/env bash
# =============================================================
# clickhouse-query.sh – Run a ClickHouse query from terminal
# Usage: ./scripts/clickhouse-query.sh "SELECT count() FROM analytics.events"
# =============================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env
if [[ -f "$ROOT_DIR/.env" ]]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
fi

QUERY="${1:-SELECT version()}"

docker compose -f "$ROOT_DIR/docker-compose.yml" exec clickhouse \
    clickhouse-client \
        --user="${CLICKHOUSE_USER:-analytics}" \
        --password="${CLICKHOUSE_PASSWORD:-analytics_secret}" \
        --database="${CLICKHOUSE_DB:-analytics}" \
        --query="$QUERY"
