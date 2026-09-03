-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- Pipeline latency, per minute, from broker-stamped timestamps.
--
-- Kafka append times are the only trustworthy per-event clocks here:
-- RisingWave's proctime() is barrier-aligned (0-1s early bias), so nothing
-- below is measured from proctime.
--
-- What this file provides:
--   ingest_to_kafka_*  : Ruby `ingested_at` -> raw event appended to Kafka
--                        (`pipeline_latency`)
--   usage_*            : Ruby `ingested_at` -> usage bucket row COMPUTED AND
--                        EMITTED (`usage_latency`, via a debug topic loopback)
--
-- The end-to-end figure (ingest -> enriched row QUERYABLE) is NOT here: it is
-- a ClickHouse query since 2026-08-24, see the block above `usage_latency`.
--
-- `ingested_at` is a naive UTC timestamp; it is pinned to UTC before being
-- compared with the timestamptz broker stamps. It is also OPTIONAL in the
-- payload (see sql/05_usage.sql): an event without it counts toward `events`
-- but contributes NULL to the latency aggregates, which AVG/MIN/MAX skip — a
-- window can therefore report events with empty latencies rather than zero.
CREATE MATERIALIZED VIEW IF NOT EXISTS pipeline_latency AS
SELECT
    window_start,
    COUNT(*) AS events,
    ROUND(AVG(EXTRACT(EPOCH FROM (kafka_timestamp - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS ingest_to_kafka_avg_ms,
    ROUND(MAX(EXTRACT(EPOCH FROM (kafka_timestamp - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS ingest_to_kafka_max_ms
FROM TUMBLE(events_raw, kafka_timestamp, INTERVAL '1 minute')
GROUP BY window_start;

-- e2e latency (ingest -> enriched event QUERYABLE) is measured in ClickHouse
-- since 2026-08-24, not here. The expanded shadow used to be produced to an
-- `events_enriched_expanded_shadow` Kafka topic, which this file looped back
-- in as `events_enriched_shadow_loopback` to compare the broker append time
-- against Ruby's `ingested_at` in a `pipeline_latency_e2e` MV. That sink now
-- writes ClickHouse (06_sinks.sql), so both clocks live on the shadow row:
-- `ingested_at` carried from the API, `enriched_at` stamped by ClickHouse at
-- insert. The equivalent query, and a strictly better endpoint (it measures
-- SERVING visibility, not topic arrival):
--
--   SELECT toStartOfMinute(enriched_at) AS minute,
--          count() AS events,
--          round(avg(dateDiff('millisecond', ingested_at, enriched_at))) AS e2e_avg_ms,
--          min(dateDiff('millisecond', ingested_at, enriched_at)) AS e2e_min_ms,
--          max(dateDiff('millisecond', ingested_at, enriched_at)) AS e2e_max_ms
--   FROM default.events_enriched_expanded_rw_shadow
--   WHERE enriched_at > now() - INTERVAL 15 MINUTE
--   GROUP BY minute ORDER BY minute DESC;
--
-- CAVEAT: rows delivered by a sink BACKFILL carry a meaningless e2e (they were
-- ingested whenever, inserted now). Filter to `enriched_at` after the backfill
-- completed, or to events produced live.

-- Usage-path latency: every event updates one usage_buckets_15m row; sink
-- those updates to a debug topic and loop them back to compare the broker
-- append time with the event's ingested_at.
--
-- This measures ingest -> bucket row COMPUTED AND EMITTED. Serving adds the
-- ClickHouse sink flush on top (~0.3s quiet, measured 2026-08-21).
CREATE SINK IF NOT EXISTS usage_realtime_updates_sink AS
SELECT
    organization_id,
    subscription_id,
    bucket,
    charge_id,
    charge_filter_id,
    grouped_by,
    aggregation_type,
    events_count,
    units,
    last_ingested_at
FROM usage_buckets_15m
WITH (
    connector = 'kafka',
    topic = 'usage_realtime_updates',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,subscription_id,bucket,charge_id,charge_filter_id,grouped_by'
) FORMAT PLAIN ENCODE JSON (force_append_only = 'true');

CREATE SOURCE IF NOT EXISTS usage_updates_loopback (
    last_ingested_at TIMESTAMP
) INCLUDE timestamp AS emitted_at
WITH (
    connector = 'kafka',
    topic = 'usage_realtime_updates',
    properties.bootstrap.server = 'redpanda:9092',
    scan.startup.mode = 'latest'
) FORMAT PLAIN ENCODE JSON;

CREATE MATERIALIZED VIEW IF NOT EXISTS usage_latency AS
SELECT
    window_start,
    COUNT(*) AS usage_updates,
    ROUND(AVG(EXTRACT(EPOCH FROM (emitted_at - last_ingested_at AT TIME ZONE 'UTC'))) * 1000) AS usage_avg_ms,
    ROUND(MIN(EXTRACT(EPOCH FROM (emitted_at - last_ingested_at AT TIME ZONE 'UTC'))) * 1000) AS usage_min_ms,
    ROUND(MAX(EXTRACT(EPOCH FROM (emitted_at - last_ingested_at AT TIME ZONE 'UTC'))) * 1000) AS usage_max_ms
FROM TUMBLE(usage_updates_loopback, emitted_at, INTERVAL '1 minute')
GROUP BY window_start;
