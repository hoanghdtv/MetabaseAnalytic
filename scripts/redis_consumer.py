#!/usr/bin/env python3
"""Simple Redis Streams consumer that batches messages and inserts into ClickHouse.

Usage example:
  pip install redis requests
  python scripts/redis_consumer.py --redis-host localhost --redis-port 6379 \
    --stream events_stream --group ch_group --consumer consumer-1 \
    --clickhouse http://localhost:8123

This script is intentionally small and dependency-light. For production use prefer
using the `clickhouse-driver` (native protocol) and robust retry/backoff logic.
"""
import argparse
import gzip
import io
import json
import logging
import signal
import sys
import time

from redis import Redis
import requests


LOG = logging.getLogger("redis_consumer")


def gzip_bytes(b: bytes) -> bytes:
    buf = io.BytesIO()
    with gzip.GzipFile(fileobj=buf, mode="wb") as f:
        f.write(b)
    return buf.getvalue()


def run(args):
    r = Redis(host=args.redis_host, port=args.redis_port, decode_responses=True)

    # Ensure consumer group exists (MKSTREAM creates stream if missing)
    try:
        r.xgroup_create(args.stream, args.group, id="$", mkstream=True)
    except Exception:
        # group may already exist
        pass

    ch_insert_url = f"{args.clickhouse}/?query=INSERT%20INTO%20{args.clickhouse_table}%20FORMAT%20JSONEachRow"

    running = True

    def _handle(sig, frame):
        nonlocal running
        LOG.info("Shutdown requested, exiting main loop")
        running = False

    signal.signal(signal.SIGINT, _handle)
    signal.signal(signal.SIGTERM, _handle)

    while running:
        try:
            entries = r.xreadgroup(args.group, args.consumer, {args.stream: '>'}, count=args.batch, block=args.block_ms)
        except Exception as e:
            LOG.exception("Redis read error: %s", e)
            time.sleep(1)
            continue

        if not entries:
            continue

        docs = []
        ids = []
        for stream_name, messages in entries:
            for msg_id, fields in messages:
                # Expect a 'payload' field containing JSON; fallback to full fields
                payload_raw = fields.get('payload') or json.dumps(fields)
                try:
                    payload = json.loads(payload_raw)
                except Exception:
                    payload = {"raw": payload_raw}

                doc = {
                    "event_time": payload.get("ts") or payload.get("timestamp") or time.strftime("%Y-%m-%d %H:%M:%S"),
                    "user_id": payload.get("user_id") or payload.get("uid") or "",
                    "event_type": payload.get("event_type") or payload.get("type") or "",
                    "properties": json.dumps(payload.get("properties", {})),
                    "event_id": payload.get("event_id") or msg_id,
                }
                docs.append(doc)
                ids.append(msg_id)

        if not docs:
            continue

        body = "\n".join(json.dumps(d) for d in docs).encode("utf-8")
        if args.gzip:
            body = gzip_bytes(body)

        headers = {}
        if args.gzip:
            headers['Content-Encoding'] = 'gzip'

        try:
            resp = requests.post(ch_insert_url, data=body, headers=headers, timeout=args.timeout)
        except Exception as e:
            LOG.exception("Failed to post to ClickHouse: %s", e)
            # Do not ack messages; sleep a bit to avoid tight loop
            time.sleep(1)
            continue

        if resp.status_code == 200 and (resp.text == '' or 'Ok.' in resp.text):
            try:
                r.xack(args.stream, args.group, *ids)
            except Exception:
                LOG.exception("Failed to xack messages")
        else:
            LOG.error("ClickHouse insert failed: %s %s", resp.status_code, resp.text)
            # optionally send to dead-letter or retry later
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--redis-host", default="localhost")
    parser.add_argument("--redis-port", type=int, default=6379)
    parser.add_argument("--stream", default="events_stream")
    parser.add_argument("--group", default="ch_group")
    parser.add_argument("--consumer", default="consumer-1")
    parser.add_argument("--batch", type=int, default=200)
    parser.add_argument("--block-ms", type=int, default=5000)
    parser.add_argument("--clickhouse", default="http://localhost:8123")
    parser.add_argument("--clickhouse-table", default="events")
    parser.add_argument("--timeout", type=int, default=10)
    parser.add_argument("--gzip", action='store_true', help="Enable gzip compression for HTTP body")
    parser.add_argument("--log-level", default="INFO")

    args = parser.parse_args()

    logging.basicConfig(level=getattr(logging, args.log_level.upper(), logging.INFO), format="%(asctime)s %(levelname)s %(message)s")

    run(args)


if __name__ == '__main__':
    main()
