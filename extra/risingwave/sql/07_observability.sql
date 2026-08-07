-- Pipeline latency, per minute, from broker-stamped timestamps.
--
-- Kafka append times are the only trustworthy per-event clocks here:
-- RisingWave's proctime() is barrier-aligned (0-1s early bias), so the
-- end-to-end figure is measured by reading the shadow output topic back and
-- comparing its broker timestamp with the original Ruby `ingested_at`.
--
--   ingest_to_kafka_*  : Ruby `ingested_at` -> raw event appended to Kafka
--   e2e_*              : Ruby `ingested_at` -> enriched event appended to the
--                        shadow topic (source read + joins + ranking + sink,
--                        including barrier/checkpoint overhead)
--
-- `ingested_at` is a naive UTC timestamp; it is pinned to UTC before being
-- compared with the timestamptz broker stamps.
CREATE MATERIALIZED VIEW IF NOT EXISTS pipeline_latency AS
SELECT
    window_start,
    COUNT(*) AS events,
    ROUND(AVG(EXTRACT(EPOCH FROM (kafka_timestamp - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS ingest_to_kafka_avg_ms,
    ROUND(MAX(EXTRACT(EPOCH FROM (kafka_timestamp - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS ingest_to_kafka_max_ms
FROM TUMBLE(events_raw, kafka_timestamp, INTERVAL '1 minute')
GROUP BY window_start;

-- Loop the shadow topic back in; only the fields needed for latency.
CREATE SOURCE IF NOT EXISTS events_enriched_shadow_loopback (
    transaction_id VARCHAR,
    ingested_at TIMESTAMP
) INCLUDE timestamp AS enriched_at
WITH (
    connector = 'kafka',
    topic = 'events_enriched_expanded_shadow',
    properties.bootstrap.server = 'redpanda:9092',
    scan.startup.mode = 'latest'
) FORMAT PLAIN ENCODE JSON;

CREATE MATERIALIZED VIEW IF NOT EXISTS pipeline_latency_e2e AS
SELECT
    window_start,
    COUNT(*) AS events,
    ROUND(AVG(EXTRACT(EPOCH FROM (enriched_at - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS e2e_avg_ms,
    ROUND(MIN(EXTRACT(EPOCH FROM (enriched_at - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS e2e_min_ms,
    ROUND(MAX(EXTRACT(EPOCH FROM (enriched_at - ingested_at AT TIME ZONE 'UTC'))) * 1000) AS e2e_max_ms
FROM TUMBLE(events_enriched_shadow_loopback, enriched_at, INTERVAL '1 minute')
GROUP BY window_start;

-- Usage-path latency: every event updates one usage_realtime row; sink those
-- updates to a debug topic and loop them back to compare the broker append
-- time with the event's ingested_at.
--
-- This measures ingest -> usage row COMPUTED AND EMITTED. Reading the MV over
-- pgwire is checkpoint-consistent, so *visibility* adds up to one barrier
-- interval (default 1s) on top — measure that with usage_latency_probe.sh.
CREATE SINK IF NOT EXISTS usage_realtime_updates_sink AS
SELECT
    organization_id,
    subscription_id,
    charge_id,
    charge_filter_id,
    grouped_by,
    aggregation_type,
    events_count,
    units,
    last_ingested_at
FROM usage_realtime
WITH (
    connector = 'kafka',
    topic = 'usage_realtime_updates',
    properties.bootstrap.server = 'redpanda:9092',
    primary_key = 'organization_id,subscription_id,charge_id,charge_filter_id,grouped_by'
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
