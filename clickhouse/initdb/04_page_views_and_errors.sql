-- =============================================================
-- 04_page_views.sql – Page view tracking
-- =============================================================

CREATE TABLE IF NOT EXISTS analytics.page_views
(
    view_id         UUID            DEFAULT generateUUIDv4(),
    app_id          LowCardinality(String),
    session_id      String,
    user_id         String,
    anonymous_id    String,

    -- Page
    url             String,
    path            String          MATERIALIZED path(url),
    title           String          DEFAULT '',
    referrer        String          DEFAULT '',

    -- Timing
    viewed_at       DateTime64(3, 'UTC'),
    time_on_page_s  Nullable(UInt32),

    -- Device
    platform        LowCardinality(String)  DEFAULT '',
    device_type     LowCardinality(String)  DEFAULT '',
    browser         LowCardinality(String)  DEFAULT '',

    -- Geo
    country_code    LowCardinality(String)  DEFAULT '',
    city            String                  DEFAULT '',

    date            Date    MATERIALIZED toDate(viewed_at)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, viewed_at, session_id)
TTL viewed_at + INTERVAL 2 YEAR
SETTINGS index_granularity = 8192;


-- =============================================================
-- 05_errors.sql – Application error tracking
-- =============================================================

CREATE TABLE IF NOT EXISTS analytics.errors
(
    error_id        UUID            DEFAULT generateUUIDv4(),
    app_id          LowCardinality(String),
    session_id      String          DEFAULT '',
    user_id         String          DEFAULT '',

    -- Error details
    error_type      LowCardinality(String),
    error_message   String,
    stack_trace     String          DEFAULT '',
    component       String          DEFAULT '',
    severity        LowCardinality(String)  DEFAULT 'error', -- debug|info|warning|error|critical

    -- Context
    page_url        String          DEFAULT '',
    platform        LowCardinality(String)  DEFAULT '',
    app_version     LowCardinality(String)  DEFAULT '',
    os              LowCardinality(String)  DEFAULT '',
    browser         LowCardinality(String)  DEFAULT '',

    -- Timing
    occurred_at     DateTime64(3, 'UTC'),
    received_at     DateTime64(3, 'UTC')    DEFAULT now64(3, 'UTC'),

    -- Extra context
    extra           String          DEFAULT '{}',

    date            Date    MATERIALIZED toDate(occurred_at)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, error_type, occurred_at)
TTL occurred_at + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;
