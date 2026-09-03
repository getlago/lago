-- STAGE 0: billable-metric enrichment + first-wins dedup.
--
-- This is the RisingWave subtree that hit the wall, and the reason this whole
-- comparison exists. On RisingWave this stage saturated at 36-37k ev/s,
-- invariant across six configurations, localised to fragment 119: a
-- NOW()-driven DynamicFilter feeding the dedup, capping ~580 ev/s/actor.
--
-- ============================================================================
-- THE STRUCTURAL DIFFERENCE BEING TESTED — DO NOT "PORT" IT AWAY
-- ============================================================================
-- The RisingWave version carries `WHERE e.kafka_timestamp > now() - INTERVAL
-- '32 days'`. That filter is NOT a business rule: it exists to BOUND THE DEDUP
-- STATE. Its expiry retractions sweep the operator's state clean, and the
-- whole append-only firewall-table architecture (retention_seconds, force_
-- append_only sinks) exists to keep those retractions from leaking downstream.
-- That construct IS fragment 119. It is the measured ceiling.
--
-- It is deliberately ABSENT here. Flink bounds the same state with
-- `table.exec.state.ttl` (set to 32 days in LagoUsageJob), handled by the
-- state backend — no clock in the dataflow, nothing to retract, no firewall
-- tables. Reintroducing a `NOW()`-based filter would rebuild the exact thing
-- we are trying to measure our way out of.
--
-- Window semantics are unchanged: dedup key is the production
-- ReplacingMergeTree key, first ingestion wins, answered over ~32 days. A
-- re-send more than 32 days after first ingestion passes dedup and lands as a
-- duplicate downstream — the same agreed contract as RisingWave. There is
-- deliberately no in-stream correction path.
-- ============================================================================
--
-- Requires: 00_source_events_raw.sql (events_raw) and 01_cdc_dimensions.sql
-- (billable_metrics). Declaring the other five dimension tables costs nothing:
-- a Flink CREATE TABLE is catalog metadata only, and a CDC source — with its
-- replication slot — is instantiated only when a running query reads it. Stage
-- 0 reads billable_metrics alone, so it runs on ONE slot.

-- Blackhole first, deliberately: it measures the pipeline's compute cost with
-- the sink removed from the equation. A ceiling that moves when the sink
-- changes is a sink ceiling. Take a blackhole number BEFORE a ClickHouse one.
-- For semantic checks submit with `--stage0.sink.connector print`.
CREATE TABLE IF NOT EXISTS events_enriched_out (
    organization_id            STRING,
    external_subscription_id   STRING,
    transaction_id             STRING,
    code                       STRING,
    properties                 STRING,
    precise_total_amount_cents STRING,
    source                     STRING,
    event_ts                   DOUBLE,
    event_time                 TIMESTAMP_LTZ(3),
    ingested_at                TIMESTAMP(3),
    api_post_processed         BOOLEAN,
    billable_metric_id         STRING,
    aggregation_type_code      INT,
    field_name                 STRING,
    expression                 STRING,
    recurring                  BOOLEAN,
    kafka_timestamp            TIMESTAMP_LTZ(3)
) WITH (
    -- Switchable without a rebuild: `--stage0.sink.connector print` on the
    -- submit line prints every enriched row to the TaskManager stdout
    -- (scripts/logs.sh), which is how stage-0 SEMANTICS get verified;
    -- `blackhole` is the default because that is how stage-0 THROUGHPUT gets
    -- measured. Never take a performance number with `print` — the console
    -- writer is the bottleneck then, not the pipeline.
    'connector' = '${stage0.sink.connector}'
);

INSERT INTO events_enriched_out
SELECT
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    field_name,
    expression,
    recurring,
    kafka_timestamp
FROM (
    SELECT
        *,
        -- FIRST-WINS DEDUP on the production ReplacingMergeTree key.
        --
        -- ORDER BY a processing-time attribute ASCENDING is the pattern the
        -- planner recognises and compiles to a dedicated Deduplicate operator
        -- (keep-first-row), whose expiry is handled by state TTL in the state
        -- backend. Confirm that in EXPLAIN before trusting any measurement:
        -- if this shows up as a Rank/TopN behind a filter instead, we have
        -- rebuilt RisingWave's fragment 119 and the comparison is void.
        ROW_NUMBER() OVER (
            PARTITION BY organization_id, code, external_subscription_id,
                         event_ts, transaction_id
            ORDER BY flink_received_at ASC
        ) AS row_num
    FROM (
        SELECT
            e.organization_id,
            e.external_subscription_id,
            e.transaction_id,
            e.code,
            e.properties,
            e.precise_total_amount_cents,
            e.source,
            CAST(e.`timestamp` AS DOUBLE) AS event_ts,
            TO_TIMESTAMP_LTZ(CAST(CAST(e.`timestamp` AS DOUBLE) * 1000 AS BIGINT), 3) AS event_time,
            e.ingested_at,
            COALESCE(e.source_metadata.api_post_processed, false) AS api_post_processed,
            bm.id               AS billable_metric_id,
            bm.aggregation_type AS aggregation_type_code,
            bm.field_name,
            bm.expression,
            bm.recurring,
            e.kafka_timestamp,
            e.flink_received_at
        FROM events_raw AS e
        -- INNER join, matching the Go processor: a missing or deleted
        -- billable metric dead-letters the event, so no enriched row.
        --
        -- EVENT-TIME temporal join against the CDC-backed versioned table.
        -- The left side keeps no state, which is the property RisingWave got
        -- from `FOR SYSTEM_TIME AS OF PROCTIME()`. A plain JOIN here would be
        -- a regular streaming join materialising BOTH sides — 32 days of
        -- events in state — which is the thing to avoid.
        --
        -- Event-time is not a preference, it is forced: Flink rejects
        -- processing-time temporal joins. The operational consequence is that
        -- an IDLE dimension source stalls this join, because its watermark
        -- stops advancing — see table.exec.source.idle-timeout in
        -- LagoUsageJob. RisingWave's proctime join has no such failure mode.
        JOIN billable_metrics FOR SYSTEM_TIME AS OF e.event_rowtime AS bm
          ON bm.organization_id = e.organization_id
         AND bm.code = e.code
         AND bm.deleted_at IS NULL
    ) joined
) deduped
WHERE row_num = 1;
