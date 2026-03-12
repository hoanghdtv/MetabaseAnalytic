#!/usr/bin/env bash
# =============================================================
# backup.sh – Backup ClickHouse and Metabase volumes
# =============================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$ROOT_DIR/backups/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"
echo "[INFO] Backup destination: $BACKUP_DIR"

# Backup ClickHouse data volume
echo "[1/2] Backing up ClickHouse data..."
docker run --rm \
    --volumes-from analytics_clickhouse \
    -v "$BACKUP_DIR":/backup \
    alpine \
    tar czf /backup/clickhouse_data.tar.gz /var/lib/clickhouse
echo "  ✓ ClickHouse backup saved"

# Backup Metabase PostgreSQL
echo "[2/2] Backing up Metabase database (PostgreSQL)..."
ROOT_DIR="$ROOT_DIR" source <(grep -v '^#' "$ROOT_DIR/.env" | sed 's/^/export /')
docker compose -f "$ROOT_DIR/docker-compose.yml" exec -T metabase_db \
    pg_dump -U "${MB_DB_USER:-metabase}" "${MB_DB_DBNAME:-metabase}" \
    | gzip > "$BACKUP_DIR/metabase_db.sql.gz"
echo "  ✓ Metabase DB backup saved"

echo ""
echo "[DONE] Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
