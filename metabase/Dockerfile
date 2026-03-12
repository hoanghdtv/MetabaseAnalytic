# =============================================================
# Metabase with ClickHouse driver
# =============================================================
ARG METABASE_VERSION=v0.52.5
FROM metabase/metabase:${METABASE_VERSION}

ARG CLICKHOUSE_DRIVER_VERSION=1.5.0

USER root

# Install curl for downloading the driver
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Download ClickHouse driver from official GitHub releases
RUN mkdir -p /plugins && \
    curl -sSL \
      "https://github.com/ClickHouse/metabase-clickhouse-driver/releases/download/${CLICKHOUSE_DRIVER_VERSION}/clickhouse.metabase-driver.jar" \
      -o /plugins/clickhouse.metabase-driver.jar && \
    chmod 644 /plugins/clickhouse.metabase-driver.jar

# Back to default Metabase user
USER metabase

ENV MB_PLUGINS_DIR=/plugins
