# =============================================================
# Metabase with ClickHouse driver (multi-stage build)
# =============================================================
ARG METABASE_VERSION=v0.52.5
ARG CLICKHOUSE_DRIVER_VERSION=1.5.0

# ── Stage 1: download the driver using Alpine ─────────────────
FROM alpine:3.19 AS driver-download
ARG CLICKHOUSE_DRIVER_VERSION
RUN apk add --no-cache curl && \
    curl -sSfL \
      "https://github.com/ClickHouse/metabase-clickhouse-driver/releases/download/${CLICKHOUSE_DRIVER_VERSION}/clickhouse.metabase-driver.jar" \
      -o /clickhouse.metabase-driver.jar

# ── Stage 2: Metabase with driver copied in ───────────────────
FROM metabase/metabase:${METABASE_VERSION}
COPY --from=driver-download /clickhouse.metabase-driver.jar /plugins/clickhouse.metabase-driver.jar

ENV MB_PLUGINS_DIR=/plugins
