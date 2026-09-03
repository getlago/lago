-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- Raw billing events, exactly as produced to Kafka by the API / ingest services.
--
-- Notes:
--  * `timestamp` is declared VARCHAR because producers send it as a JSON string
--    (e.g. "1786027675.796"); it is cast to DOUBLE PRECISION downstream.
--  * `scan.startup.mode = 'latest'`: the shadow pipeline starts from new events
--    only. Switch to 'earliest' to replay the whole topic.
CREATE SOURCE IF NOT EXISTS events_raw (
    organization_id VARCHAR,
    external_subscription_id VARCHAR,
    transaction_id VARCHAR,
    code VARCHAR,
    properties JSONB,
    precise_total_amount_cents VARCHAR,
    source VARCHAR,
    "timestamp" VARCHAR,
    -- The payload also carries source_metadata.reprocess; deliberately not
    -- declared — events are immutable, there is no in-stream correction path.
    source_metadata STRUCT<api_post_processed BOOLEAN>,
    ingested_at TIMESTAMP,
    -- proctime() is BARRIER-ALIGNED (0-1s early bias) — fine for temporal
    -- filters / future state TTL, do not use for latency math; latency uses
    -- broker timestamps (kafka_timestamp, see 07) and the ClickHouse insert
    -- stamp (events_enriched_expanded_rw_shadow.enriched_at).
    rw_received_at TIMESTAMPTZ AS proctime()
) INCLUDE timestamp AS kafka_timestamp
WITH (
    connector = 'kafka',
    topic = 'events-raw',
    properties.bootstrap.server = 'redpanda:9092',
    scan.startup.mode = 'latest'
) FORMAT PLAIN ENCODE JSON;
