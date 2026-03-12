-- =============================================================
-- 02_events.sql – Core event tracking table
-- =============================================================

-- Raw events table (append-only, immutable)
CREATE TABLE IF NOT EXISTS analytics.events
(
    -- Identifiers
    event_id        UUID            DEFAULT generateUUIDv4(),
    app_id          LowCardinality(String),
    session_id      String,
    user_id         String,
    anonymous_id    String,

    -- Event metadata
    event_name      LowCardinality(String),
    event_category  LowCardinality(String)   DEFAULT '',
    event_label     String                   DEFAULT '',
    event_value     Nullable(Float64),

    -- Timing
    event_time      DateTime64(3, 'UTC'),
    received_at     DateTime64(3, 'UTC')     DEFAULT now64(3, 'UTC'),

    -- Page / screen context
    page_url        String                   DEFAULT '',
    page_title      String                   DEFAULT '',
    page_referrer   String                   DEFAULT '',
    screen_name     String                   DEFAULT '',

    -- Device / environment
    platform        LowCardinality(String)   DEFAULT '',   -- web | ios | android
    os              LowCardinality(String)   DEFAULT '',
    os_version      String                   DEFAULT '',
    browser         LowCardinality(String)   DEFAULT '',
    browser_version String                   DEFAULT '',
    device_type     LowCardinality(String)   DEFAULT '',   -- desktop | mobile | tablet

    -- Geo
    country_code    LowCardinality(String)   DEFAULT '',
    region          String                   DEFAULT '',
    city            String                   DEFAULT '',

    -- UTM / acquisition
    utm_source      LowCardinality(String)   DEFAULT '',
    utm_medium      LowCardinality(String)   DEFAULT '',
    utm_campaign    String                   DEFAULT '',
    utm_content     String                   DEFAULT '',
    utm_term        String                   DEFAULT '',

    -- Arbitrary properties stored as JSON string
    properties      String                   DEFAULT '{}',

    -- Partitioning helper
    date            Date                     MATERIALIZED toDate(event_time)
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, event_name, event_time, user_id)
TTL event_time + INTERVAL 2 YEAR
SETTINGS index_granularity = 8192;


-- Convenient view with parsed date parts
CREATE VIEW IF NOT EXISTS analytics.events_view AS
SELECT
    *,
    toDate(event_time)           AS event_date,
    toHour(event_time)           AS event_hour,
    toDayOfWeek(event_time)      AS day_of_week,
    toStartOfWeek(event_time)    AS event_week,
    toStartOfMonth(event_time)   AS event_month
FROM analytics.events;
