-- =============================================================
-- 06_sample_data.sql – Seed sample data for testing dashboards
-- =============================================================

-- Insert 30 days of synthetic events
INSERT INTO analytics.events
    (event_id, app_id, session_id, user_id, anonymous_id,
     event_name, event_category, page_url, page_title,
     platform, os, browser, device_type,
     country_code, city,
     utm_source, utm_medium, utm_campaign,
     event_time)
SELECT
    generateUUIDv4(),
    arrayElement(['my_app', 'my_app', 'my_app', 'mobile_app'], rand() % 4 + 1)  AS app_id,
    concat('sess_', toString(number % 5000))                    AS session_id,
    concat('user_', toString(number % 2000))                    AS user_id,
    concat('anon_', toString(number % 2000))                    AS anonymous_id,
    arrayElement(['page_view', 'page_view', 'page_view',
                  'click', 'click',
                  'session_start', 'session_end',
                  'purchase', 'signup', 'login'], rand() % 10 + 1) AS event_name,
    arrayElement(['navigation', 'engagement', 'conversion', 'system'], rand() % 4 + 1),
    concat('https://example.com/', arrayElement(['', 'dashboard', 'settings',
        'pricing', 'blog', 'about'], rand() % 6 + 1)),
    arrayElement(['Home', 'Dashboard', 'Settings', 'Pricing', 'Blog', 'About'], rand() % 6 + 1),
    arrayElement(['web', 'web', 'web', 'ios', 'android'], rand() % 5 + 1),
    arrayElement(['Windows', 'macOS', 'Linux', 'iOS', 'Android'], rand() % 5 + 1),
    arrayElement(['Chrome', 'Firefox', 'Safari', 'Edge'], rand() % 4 + 1),
    arrayElement(['desktop', 'desktop', 'mobile', 'tablet'], rand() % 4 + 1),
    arrayElement(['US', 'VN', 'GB', 'DE', 'SG', 'JP', 'AU', 'FR'], rand() % 8 + 1),
    arrayElement(['New York', 'Hanoi', 'London', 'Berlin', 'Singapore', 'Tokyo'], rand() % 6 + 1),
    arrayElement(['google', 'facebook', 'twitter', 'direct', 'email', ''], rand() % 6 + 1),
    arrayElement(['cpc', 'organic', 'social', 'email', 'referral', ''], rand() % 6 + 1),
    arrayElement(['summer_2025', 'brand_awareness', 'product_launch', ''], rand() % 4 + 1),
    now() - toIntervalDay(number % 30) - toIntervalHour(rand() % 24) - toIntervalMinute(rand() % 60)
FROM numbers(100000);

-- Insert sample sessions
INSERT INTO analytics.sessions
    (session_id, app_id, user_id, anonymous_id,
     started_at, ended_at, duration_seconds,
     page_view_count, event_count,
     entry_page, exit_page,
     platform, browser, device_type,
     country_code, city,
     utm_source, utm_medium, utm_campaign,
     is_bounce, converted)
SELECT
    concat('sess_', toString(number % 5000))          AS session_id,
    arrayElement(['my_app', 'mobile_app'], rand() % 2 + 1),
    concat('user_', toString(number % 2000)),
    concat('anon_', toString(number % 2000)),
    now() - toIntervalDay(number % 30),
    now() - toIntervalDay(number % 30) + toIntervalSecond(rand() % 1800 + 30),
    rand() % 1800 + 30,
    rand() % 10 + 1,
    rand() % 20 + 1,
    arrayElement(['/', '/dashboard', '/pricing', '/blog'], rand() % 4 + 1),
    arrayElement(['/', '/dashboard', '/pricing', '/blog'], rand() % 4 + 1),
    arrayElement(['web', 'ios', 'android'], rand() % 3 + 1),
    arrayElement(['Chrome', 'Firefox', 'Safari', 'Edge'], rand() % 4 + 1),
    arrayElement(['desktop', 'mobile', 'tablet'], rand() % 3 + 1),
    arrayElement(['US', 'VN', 'GB', 'DE', 'SG'], rand() % 5 + 1),
    arrayElement(['New York', 'Hanoi', 'London', 'Berlin', 'Singapore'], rand() % 5 + 1),
    arrayElement(['google', 'facebook', 'direct', ''], rand() % 4 + 1),
    arrayElement(['cpc', 'organic', 'social', ''], rand() % 4 + 1),
    arrayElement(['summer_2025', 'product_launch', ''], rand() % 3 + 1),
    rand() % 5 = 0,
    rand() % 10 = 0
FROM numbers(5000);

-- Insert sample errors
INSERT INTO analytics.errors
    (app_id, session_id, user_id,
     error_type, error_message, component, severity,
     page_url, platform, app_version,
     occurred_at)
SELECT
    arrayElement(['my_app', 'mobile_app'], rand() % 2 + 1),
    concat('sess_', toString(number % 500)),
    concat('user_', toString(number % 200)),
    arrayElement(['TypeError', 'NetworkError', 'ReferenceError', 'SyntaxError',
                  'TimeoutError', 'AuthError'], rand() % 6 + 1),
    arrayElement(['Cannot read properties of undefined',
                  'Network request failed',
                  'Variable is not defined',
                  'Request timeout after 30s',
                  'Authentication token expired',
                  'Unexpected token in JSON'], rand() % 6 + 1),
    arrayElement(['UserService', 'APIClient', 'AuthModule', 'Router', 'DataLayer'],
                 rand() % 5 + 1),
    arrayElement(['error', 'warning', 'critical', 'info'], rand() % 4 + 1),
    concat('https://example.com/', arrayElement(['dashboard', 'api', 'auth', ''], rand() % 4 + 1)),
    arrayElement(['web', 'ios', 'android'], rand() % 3 + 1),
    arrayElement(['1.0.0', '1.1.0', '1.2.0', '2.0.0'], rand() % 4 + 1),
    now() - toIntervalDay(number % 30) - toIntervalHour(rand() % 24)
FROM numbers(2000);
