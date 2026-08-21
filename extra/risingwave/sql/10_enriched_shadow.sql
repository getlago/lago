-- Shadow of the Go processor's *enriched* (non-expanded) output.
--
-- The Go path (processor.go / ProduceEnrichedEvent -> events_enriched topic ->
-- CH events_enriched_mv) emits ONE row per event, with no charge fan-out, and
-- only needs the billable metric: the columns persisted in ClickHouse
-- events_enriched are (org, external_subscription_id, code, timestamp,
-- transaction_id, properties, value, precise_total_amount_cents).
-- Subscription/charge enrichment never reaches that table.
--
-- This is a bare projection over the shared `events_enriched` stage
-- (04_enrichment.sql), which already applies the INNER billable_metrics
-- temporal join (a missing/deleted BM dead-letters the event in Go, so no
-- enriched row is produced) and dedups on exactly the production
-- ReplacingMergeTree key (org, code, external_subscription_id, timestamp,
-- transaction_id) — first ingestion wins, so every row arriving here is
-- unique on that key and the shadow CH table can stay a plain MergeTree
-- with no deduplication of its own.
--
-- What stays specific to this shadow:
--  * value: '1' for count, else fmt.Sprintf("%v", properties[field_name]) —
--    including Go's quirk of emitting the literal string "<nil>" when the
--    property is absent or JSON null, mirrored so parity diffs stay quiet.
--
-- State retention: events older than 32 days (by Kafka broker arrival time)
-- are expired from this MV by the temporal filter. Expiry deletes are
-- dropped at the sink (force_append_only) — ClickHouse keeps the full
-- history. NOTE: the shared dedup state in 04's `events_enriched` is NOT
-- bounded by this filter (a retracting operator upstream of the stage-1
-- temporal joins would demote them to non-append-only); bounding it is
-- ROADMAP section 1 "State TTL".
--
-- Known parity gaps (same as the expanded shadow):
--  * custom expressions (billable_metrics.expression) are not evaluated
--    (phase 2, WASM UDF) — BMs with an expression and source != HTTP_RUBY
--    will diff on value/properties.
--  * Go formats numbers via %v (float64), so exotic cases like 1e+21 render
--    differently than JSONB ->> text extraction.
CREATE MATERIALIZED VIEW IF NOT EXISTS events_enriched_rw_shadow AS
SELECT
    organization_id,
    external_subscription_id,
    code,
    -- already timestamptz; the ClickHouse sink rejects naive timestamps
    to_timestamp(event_ts) AS "timestamp",
    transaction_id,
    properties::VARCHAR AS properties_json,
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE COALESCE(properties ->> field_name, '<nil>')
    END AS value,
    NULLIF(precise_total_amount_cents, '')::DECIMAL AS precise_total_amount_cents,
    -- Latency instrumentation, not part of the events_enriched shape:
    -- rw_enriched_at = proctime() at the source, i.e. when RisingWave picked
    -- the event up for enrichment. CAVEAT: barrier-aligned, reads up to one
    -- barrier interval EARLY (250ms dev / 1s default) — fine as an "RW is
    -- enriching now" marker, don't trust it below that resolution (broker
    -- time stays available as kafka_timestamp on events_raw). Compare against
    -- enriched_at stamped by ClickHouse at insert. ingested_at (Lago API
    -- ingest) is kept RW-side only.
    rw_received_at AS rw_enriched_at,
    ingested_at
FROM events_enriched
WHERE kafka_timestamp > now() - INTERVAL '32 days';

-- Insert-only sink into the plain MergeTree created by
-- clickhouse/events_enriched_rw_shadow.sql. force_append_only drops the
-- retractions the 32-day temporal filter emits on expiry, so ClickHouse
-- retains rows RisingWave has already forgotten. enriched_at, properties
-- (Map), sorted_properties and decimal_value are stamped/derived
-- ClickHouse-side, exactly like the production Kafka-queue path.
CREATE SINK IF NOT EXISTS events_enriched_rw_shadow_sink AS
SELECT
    organization_id,
    external_subscription_id,
    code,
    "timestamp",
    transaction_id,
    properties_json,
    value,
    precise_total_amount_cents,
    rw_enriched_at
FROM events_enriched_rw_shadow
WITH (
    connector = 'clickhouse',
    type = 'append-only',
    force_append_only = 'true',
    -- With sink decoupling on (cloud default), a ClickHouse sink only commits
    -- every N checkpoints — N defaults to 10, i.e. 10 x barrier_interval_ms
    -- between flushes (the "5s batches" observed on cloud at 500ms barriers).
    -- Commit every checkpoint instead; flush cadence = barrier interval.
    commit_checkpoint_interval = 1,
    clickhouse.url = 'http://clickhouse:8123',
    clickhouse.user = 'default',
    clickhouse.password = 'default',
    clickhouse.database = 'default',
    clickhouse.table = 'events_enriched_rw_shadow'
);
