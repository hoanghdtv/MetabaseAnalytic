-- =============================================================
-- 05_aggregations.sql – Pre-aggregated tables & materialized views
-- for fast Metabase dashboards
-- =============================================================

-- ── Daily Active Users ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics.dau_agg
(
    date            Date,
    app_id          LowCardinality(String),
    platform        LowCardinality(String),
    active_users    AggregateFunction(uniq, String),
    new_sessions    SimpleAggregateFunction(sum, UInt64),
    total_events    SimpleAggregateFunction(sum, UInt64)
)
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, platform, date);

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.dau_mv
TO analytics.dau_agg
AS
SELECT
    toDate(event_time)          AS date,
    app_id,
    platform,
    uniqState(user_id)          AS active_users,
    countIf(event_name = 'session_start')  AS new_sessions,
    count()                     AS total_events
FROM analytics.events
GROUP BY date, app_id, platform;


-- ── Event counts per day ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS analytics.event_daily_agg
(
    date            Date,
    app_id          LowCardinality(String),
    event_name      LowCardinality(String),
    event_count     SimpleAggregateFunction(sum, UInt64),
    unique_users    AggregateFunction(uniq, String)
)
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (app_id, event_name, date);

CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.event_daily_mv
TO analytics.event_daily_agg
AS
SELECT
    toDate(event_time)          AS date,
    app_id,
    event_name,
    count()                     AS event_count,
    uniqState(user_id)          AS unique_users
FROM analytics.events
GROUP BY date, app_id, event_name;


-- ── Convenient query views ───────────────────────────────────
-- DAU view (easy for Metabase)
CREATE VIEW IF NOT EXISTS analytics.v_daily_active_users AS
SELECT
    date,
    app_id,
    platform,
    uniqMerge(active_users) AS active_users,
    sum(new_sessions)        AS sessions,
    sum(total_events)        AS total_events
FROM analytics.dau_agg
GROUP BY date, app_id, platform
ORDER BY date DESC;

-- Top events view
CREATE VIEW IF NOT EXISTS analytics.v_top_events AS
SELECT
    date,
    app_id,
    event_name,
    sum(event_count)            AS event_count,
    uniqMerge(unique_users)     AS unique_users
FROM analytics.event_daily_agg
GROUP BY date, app_id, event_name
ORDER BY event_count DESC;

-- Acquisition channels view
CREATE VIEW IF NOT EXISTS analytics.v_acquisition AS
SELECT
    toDate(event_time)      AS date,
    app_id,
    utm_source,
    utm_medium,
    utm_campaign,
    count()                 AS events,
    uniq(session_id)        AS sessions,
    uniq(user_id)           AS users
FROM analytics.events
WHERE event_name = 'session_start'
GROUP BY date, app_id, utm_source, utm_medium, utm_campaign
ORDER BY date DESC, sessions DESC;

-- Retention: 7-day retention simplified
CREATE VIEW IF NOT EXISTS analytics.v_retention_7d AS
WITH
    first_seen AS (
        SELECT user_id, app_id, min(toDate(event_time)) AS first_date
        FROM analytics.events
        WHERE user_id != ''
        GROUP BY user_id, app_id
    )
SELECT
    fs.first_date,
    fs.app_id,
    count(DISTINCT fs.user_id)                                    AS cohort_size,
    countDistinctIf(e.user_id, toDate(e.event_time) >= fs.first_date + 1
        AND toDate(e.event_time) <= fs.first_date + 7)            AS retained_7d,
    round(countDistinctIf(e.user_id, toDate(e.event_time) >= fs.first_date + 1
        AND toDate(e.event_time) <= fs.first_date + 7)
        / count(DISTINCT fs.user_id) * 100, 2)                    AS retention_rate_7d
FROM first_seen fs
LEFT JOIN analytics.events e ON e.user_id = fs.user_id AND e.app_id = fs.app_id
GROUP BY fs.first_date, fs.app_id
ORDER BY fs.first_date DESC;
