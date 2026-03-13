/*
  Example ClickHouse table used by the Redis Streams consumer.
  Place this file in clickhouse/initdb/ and it will be executed on container init if your setup runs initdb scripts.

  This creates a simple MergeTree table for events. In production you may want
  to tune PARTITION/ORDER BY and consider COLLAPSING/Merge/TTL or replacing
  with AggregatingMergeTree variants depending on your dedup and retention strategy.
*/

CREATE TABLE IF NOT EXISTS events
(
    event_time DateTime,
    user_id String,
    event_type String,
    properties String,
    event_id String
)
ENGINE = MergeTree()
PARTITION BY toDate(event_time)
ORDER BY (event_type, user_id, event_time);

/* Optional: small Buffer table to absorb bursts before writing into MergeTree
   (not a replacement for durable ingestion like Kafka/Redis with persistence).
   Adjust parameters: (db, destination_table, num_shards, min_time, max_time, min_rows, max_rows, max_bytes)
*/
-- CREATE TABLE events_buffer AS events
-- ENGINE = Buffer(default, events, 16, 10, 60, 10000, 100000, 1000000);

/* Notes:
 - The consumer script provided in `scripts/redis_consumer.py` writes using
   the HTTP interface with JSONEachRow. You can also use the native binary
   protocol (faster) from client libraries that support it.
 - For deduplication (at-least-once delivery), include event_id and run
   periodic dedup/cleanup, or use a MergeTree variant suited for your workload.
*/
