# Analytics Platform – ClickHouse + Metabase (Self-hosted)

Nền tảng analytics self-hosted dành cho ứng dụng, sử dụng **ClickHouse** làm OLAP database và **Metabase** làm giao diện BI/dashboard.

## Kiến trúc

```
┌─────────────────────────────────────────────────────┐
│                   Docker Network                     │
│                                                      │
│  ┌──────────────┐     ┌──────────────────────────┐  │
│  │  ClickHouse  │◄────│       Metabase           │  │
│  │  :8123 (HTTP)│     │       :3000              │  │
│  │  :9000 (TCP) │     └──────────────────────────┘  │
│  └──────────────┘               │                   │
│                                 ▼                   │
│                     ┌──────────────────────┐        │
│                     │  PostgreSQL (metadata)│        │
│                     │  (Metabase state)     │        │
│                     └──────────────────────┘        │
└─────────────────────────────────────────────────────┘
        │                        │
  App gửi events            Xem dashboards
  qua HTTP API             tại browser
```

| Service       | Image                              | Cổng   | Mô tả                             |
|---------------|------------------------------------|--------|-----------------------------------|
| ClickHouse    | `clickhouse/clickhouse-server:24.3`| 8123, 9000 | OLAP database                 |
| Metabase      | Custom (base: metabase/metabase)    | 3000   | BI UI + ClickHouse driver         |
| PostgreSQL    | `postgres:16-alpine`               | (nội bộ)| Lưu metadata của Metabase        |

## Yêu cầu

- Docker ≥ 24.x
- Docker Compose v2
- RAM ≥ 4 GB
- Disk ≥ 20 GB

## Khởi động nhanh

```bash
# 1. Clone / mở project
cd MetabaseAnalytic

# 2. Cấp quyền thực thi scripts
chmod +x scripts/*.sh

# 3. Chạy setup (copy .env, build image, start services)
./scripts/setup.sh

# 4. Mở Metabase
open http://localhost:3000
```

Hoặc khởi động thủ công:

```bash
cp .env.example .env       # Chỉnh sửa password nếu cần
docker compose build       # Build Metabase image với ClickHouse driver
docker compose up -d       # Khởi động tất cả services
docker compose logs -f     # Theo dõi logs
```

## Cấu hình

Chỉnh sửa file `.env` để thay đổi cấu hình:

| Biến                       | Mặc định           | Mô tả                          |
|----------------------------|--------------------|--------------------------------|
| `CLICKHOUSE_PASSWORD`      | `analytics_secret` | Password ClickHouse user       |
| `MB_DB_PASS`               | `metabase_secret`  | Password PostgreSQL Metabase   |
| `METABASE_PORT`            | `3000`             | Cổng Metabase                  |
| `METABASE_VERSION`         | `v0.52.5`          | Phiên bản Metabase             |
| `CLICKHOUSE_DRIVER_VERSION`| `1.5.0`            | Phiên bản ClickHouse driver    |
| `MB_JAVA_MAX_MEM`          | `2g`               | Bộ nhớ tối đa cho Metabase JVM |

## Thêm ClickHouse vào Metabase

Sau khi đăng ký tài khoản admin tại `http://localhost:3000`:

1. Vào **Admin → Databases → Add database**
2. Chọn **ClickHouse**
3. Điền thông tin:
   - **Host**: `clickhouse` (tên service trong Docker network)
   - **Port**: `8123`
   - **Database**: `analytics`
   - **Username**: `analytics`
   - **Password**: giá trị `CLICKHOUSE_PASSWORD` trong `.env`
4. Click **Save**

## Schema database

### `analytics.events`
Bảng chính – lưu mọi event từ ứng dụng.

| Cột             | Kiểu                | Mô tả                               |
|-----------------|---------------------|-------------------------------------|
| `event_id`      | UUID                | ID duy nhất của event               |
| `app_id`        | LowCardinality(String) | ID ứng dụng                      |
| `session_id`    | String              | ID phiên                            |
| `user_id`       | String              | ID người dùng (đã đăng nhập)        |
| `event_name`    | LowCardinality(String) | Tên event (page_view, click...) |
| `event_time`    | DateTime64(3, UTC)  | Thời điểm xảy ra event             |
| `page_url`      | String              | URL trang                           |
| `platform`      | LowCardinality      | web / ios / android                 |
| `country_code`  | LowCardinality      | Mã quốc gia (VN, US, ...)          |
| `utm_source`    | LowCardinality      | Nguồn traffic                       |
| `properties`    | String (JSON)       | Thuộc tính tùy chỉnh               |

### `analytics.sessions`
Thông tin phiên người dùng.

### `analytics.page_views`
Lịch sử xem trang.

### `analytics.errors`
Lỗi ứng dụng (error tracking).

### Views tổng hợp sẵn

| View                         | Mô tả                              |
|------------------------------|------------------------------------|
| `analytics.v_daily_active_users` | DAU theo ngày, app, platform  |
| `analytics.v_top_events`     | Top events theo ngày               |
| `analytics.v_acquisition`    | Nguồn traffic (UTM)                |
| `analytics.v_retention_7d`   | Cohort retention 7 ngày            |

## Gửi event từ ứng dụng

### HTTP API (ClickHouse HTTP Interface)

```bash
# Gửi một event
curl -X POST 'http://localhost:8123/?query=INSERT+INTO+analytics.events+FORMAT+JSONEachRow' \
  -u 'analytics:analytics_secret' \
  -H 'Content-Type: application/json' \
  -d '{
    "app_id": "my_app",
    "session_id": "sess_abc123",
    "user_id": "user_456",
    "event_name": "page_view",
    "page_url": "https://myapp.com/dashboard",
    "platform": "web",
    "country_code": "VN",
    "event_time": "2026-03-12 10:00:00.000"
  }'
```

### Python

```python
import clickhouse_connect

client = clickhouse_connect.get_client(
    host='localhost', port=8123,
    username='analytics', password='analytics_secret',
    database='analytics'
)

client.insert('events', [
    {
        'app_id': 'my_app',
        'session_id': 'sess_abc123',
        'user_id': 'user_456',
        'event_name': 'purchase',
        'event_value': 99.90,
        'platform': 'web',
        'country_code': 'VN',
        'event_time': '2026-03-12 10:00:00',
    }
], column_names=['app_id','session_id','user_id','event_name',
                 'event_value','platform','country_code','event_time'])
```

### Node.js

```js
import { createClient } from '@clickhouse/client'

const client = createClient({
  url: 'http://localhost:8123',
  username: 'analytics',
  password: 'analytics_secret',
  database: 'analytics',
})

await client.insert({
  table: 'events',
  values: [{
    app_id: 'my_app',
    session_id: 'sess_abc123',
    user_id: 'user_456',
    event_name: 'click',
    platform: 'web',
    event_time: new Date().toISOString().replace('T', ' ').substring(0, 23),
  }],
  format: 'JSONEachRow',
})
```

## Các lệnh hữu ích

```bash
# Xem logs
docker compose logs -f clickhouse
docker compose logs -f metabase

# Chạy query ClickHouse
./scripts/clickhouse-query.sh "SELECT count() FROM analytics.events"

# Vào ClickHouse shell
docker compose exec clickhouse clickhouse-client -u analytics --password analytics_secret

# Backup
./scripts/backup.sh

# Dừng services
docker compose down

# Xóa hoàn toàn (bao gồm dữ liệu)
docker compose down -v
```

## Upgrade

```bash
# Cập nhật METABASE_VERSION trong .env, sau đó:
docker compose build --no-cache metabase
docker compose up -d metabase
```

## Production checklist

- [ ] Đổi tất cả password trong `.env`
- [ ] Set `MB_SITE_URL` đúng domain thật
- [ ] Cấu hình HTTPS (reverse proxy Nginx/Traefik)
- [ ] Tăng `MB_JAVA_MAX_MEM` nếu server có nhiều RAM
- [ ] Thiết lập backup định kỳ (`cron ./scripts/backup.sh`)
- [ ] Cân nhắc tăng TTL hoặc dùng S3-backed storage cho ClickHouse khi dữ liệu lớn

## License

MIT
