-- =============================================================
-- 03_sessions.sql – User sessions table
-- =============================================================

CREATE TABLE IF NOT EXISTS analytics.sessions
(
    session_id          String,
    app_id              LowCardinality(String),
    user_id             String,
    anonymous_id        String,

    -- Session timing
    started_at          DateTime64(3, 'UTC'),
    ended_at            Nullable(DateTime64(3, 'UTC')),
    duration_seconds    Nullable(UInt32),

    -- Counts
    page_view_count     UInt32   DEFAULT 0,
    event_count         UInt32   DEFAULT 0,

    -- Entry point
    entry_page          String   DEFAULT '',
    entry_referrer      String   DEFAULT '',
    exit_page           String   DEFAULT '',

    -- Device / environment (same as events for convenience)
    platform            LowCardinality(String)  DEFAULT '',
    os                  LowCardinality(String)  DEFAULT '',
    browser             LowCardinality(String)  DEFAULT '',
    device_type         LowCardinality(String)  DEFAULT '',

    -- Geo
    country_code        LowCardinality(String)  DEFAULT '',
    region              String                  DEFAULT '',
    city                String                  DEFAULT '',

    -- Acquisition
    utm_source          LowCardinality(String)  DEFAULT '',
    utm_medium          LowCardinality(String)  DEFAULT '',
    utm_campaign        String                  DEFAULT '',

    -- Conversion flag
    is_bounce           UInt8   DEFAULT 0,
    converted           UInt8   DEFAULT 0,

    date                Date    MATERIALIZED toDate(started_at)
)
ENGINE = ReplacingMergeTree(ended_at)
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, session_id)
TTL started_at + INTERVAL 2 YEAR
SETTINGS index_granularity = 8192;
