#!/usr/bin/env bash
# =============================================================
# setup.sh – First-time project setup
# =============================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=============================="
echo "  Analytics Stack – Setup"
echo "=============================="

# 1. Check .env
if [[ ! -f "$ROOT_DIR/.env" ]]; then
    echo "[INFO] Copying .env.example → .env"
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    echo "[WARN] Review $ROOT_DIR/.env and update passwords before production use."
fi

# 2. Check Docker
if ! command -v docker &>/dev/null; then
    echo "[ERROR] Docker is not installed. Please install Docker Desktop or Docker Engine."
    exit 1
fi

if ! docker info &>/dev/null; then
    echo "[ERROR] Docker daemon is not running. Please start Docker."
    exit 1
fi

# 3. Build and start services
echo ""
echo "[STEP 1/4] Building Metabase image with ClickHouse driver..."
cd "$ROOT_DIR"
docker compose build --no-cache

echo ""
echo "[STEP 2/4] Starting all services..."
docker compose up -d

echo ""
echo "[STEP 3/4] Waiting for ClickHouse to be healthy..."
ATTEMPTS=0
until docker compose exec -T clickhouse wget -qO- http://localhost:8123/ping 2>/dev/null | grep -q "Ok"; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [[ $ATTEMPTS -gt 30 ]]; then
        echo "[ERROR] ClickHouse did not become healthy in time."
        docker compose logs clickhouse
        exit 1
    fi
    echo "  ... waiting (${ATTEMPTS}/30)"
    sleep 5
done
echo "  ✓ ClickHouse is ready"

echo ""
echo "[STEP 4/4] Waiting for Metabase to be ready..."
ATTEMPTS=0
until curl -sf http://localhost:3000/api/health | grep -q '"status":"ok"'; do
    ATTEMPTS=$((ATTEMPTS + 1))
    if [[ $ATTEMPTS -gt 40 ]]; then
        echo "[ERROR] Metabase did not start in time."
        docker compose logs metabase
        exit 1
    fi
    echo "  ... waiting (${ATTEMPTS}/40)"
    sleep 10
done
echo "  ✓ Metabase is ready"

echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo "  Metabase UI  : http://localhost:3000"
echo "  ClickHouse   : http://localhost:8123"
echo ""
echo "  Next steps:"
echo "  1. Open http://localhost:3000 and complete setup wizard"
echo "  2. Add ClickHouse database (host: clickhouse, port: 8123)"
echo "  3. Import sample dashboards or create your own"
echo "============================================"
