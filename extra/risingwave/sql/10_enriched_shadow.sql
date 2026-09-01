-- DECOUPLED ClickHouse sink — same rationale as 06_sinks.sql: keeps a dead
-- ClickHouse from failing checkpoints and stalling the whole graph (see the
-- 2026-08-31 ClickHouse-outage drill). Session-scoped; Kafka sinks unaffected.
SET sink_decouple = true;

-- Shadow of the Go processor's *enriched* (non-expanded) output.
--
-- The Go path (processor.go / ProduceEnrichedEvent -> events_enriched topic ->
-- CH events_enriched_mv) emits ONE row per event, with no charge fan-out, and
-- only needs the billable metric: the columns persisted in ClickHouse
-- events_enriched are (org, external_subscription_id, code, timestamp,
-- transaction_id, properties, value, precise_total_amount_cents).
-- Subscription/charge enrichment never reaches that table.
--
-- This is a bare projection sunk DIRECTLY off the `events_enriched` firewall
-- table (04_enrichment.sql), which already applies the INNER billable_metrics
-- temporal join (a missing/deleted BM dead-letters the event in Go, so no
-- enriched row is produced) and dedups on exactly the production
-- ReplacingMergeTree key (org, code, external_subscription_id, timestamp,
-- transaction_id) — first ingestion wins, so every row arriving here is
-- unique on that key and the shadow CH table can stay a plain MergeTree with
-- no deduplication of its own.
--
-- NO INTERMEDIATE MV (removed 2026-08-24). Until then this file materialized
-- an `events_enriched_rw_shadow` MV and sank off that — a residue of the
-- pre-firewall topology (before 24be4ed, `events_enriched` was ITSELF this
-- file's MV). Once stage 0 became an append-only TABLE the hop only cost a
-- second materialized copy of the 32-day working set, an extra streaming job,
-- and a barrier hop of latency. The sibling shadow in 06_sinks.sql sinks off
-- `events_expanded` the same way. Parity/debug queries lost nothing: the
-- upstream is a table, so run the projection below as an ad-hoc SELECT.
--
-- NO 32-DAY TEMPORAL FILTER. It existed to bound the removed MV's own state;
-- a projection sink has no operator state to sweep. RW-side boundedness comes
-- from the table's `retention_seconds` (33 days), whose physical reclaim emits
-- NO changelog events (canary-verified) — ClickHouse keeps forever-history.
--
-- NO force_append_only. The upstream is an APPEND ONLY table read by a
-- stateless projection, so the changelog is insert-only and `type =
-- 'append-only'` binds on its own. Do NOT add force_append_only back as
-- belt-and-braces: it rewrites UpdateInsert into Insert (ROADMAP §0), so it
-- would launder a future retracting operator into DUPLICATE rows in a plain
-- MergeTree. Without it, such a change fails loudly at CREATE SINK instead.
--
-- What stays specific to this shadow:
--  * value: '1' for count, else fmt.Sprintf("%v", properties[field_name]) —
--    including Go's quirk of emitting the literal string "<nil>" when the
--    property is absent or JSON null, mirrored so parity diffs stay quiet.
--  * ingested_at (Lago API ingest) and kafka_timestamp are NOT sunk; they stay
--    RW-side on the table for latency work (07_observability.sql).
--
-- CAVEAT on rebuilds: a sink BACKFILLS its upstream snapshot at CREATE time,
-- and CH `events_enriched_rw_shadow` is a plain MergeTree that counts
-- duplicates. Truncate it (dev) or plan CH-side dedup (prod) before
-- recreating this sink against a populated table.
--
-- Known parity gaps (same as the expanded shadow):
--  * custom expressions (billable_metrics.expression) are not evaluated
--    (phase 2, WASM UDF) — BMs with an expression and source != HTTP_RUBY
--    will diff on value/properties.
--  * Go formats numbers via %v (float64), so exotic cases like 1e+21 render
--    differently than JSONB ->> text extraction.
--
-- Insert-only sink into the plain MergeTree created by
-- clickhouse/events_enriched_rw_shadow.sql. enriched_at, properties (Map),
-- sorted_properties and decimal_value are stamped/derived ClickHouse-side,
-- exactly like the production Kafka-queue path.
CREATE SINK IF NOT EXISTS events_enriched_rw_shadow_sink AS
SELECT
    organization_id,
    external_subscription_id,
    code,
    -- already timestamptz; the ClickHouse sink rejects naive timestamps
    to_timestamp(event_ts) AS "timestamp",
    transaction_id,
    -- COALESCE: an event with no `properties` key at all is legal input and
    -- would otherwise NULL a non-nullable ClickHouse column; '{}' is what the
    -- production path stores for it.
    COALESCE(properties::VARCHAR, '{}') AS properties_json,
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE COALESCE(properties ->> field_name, '<nil>')
    END AS value,
    NULLIF(precise_total_amount_cents, '')::DECIMAL AS precise_total_amount_cents,
    -- Latency instrumentation, not part of the events_enriched shape:
    -- rw_enriched_at = proctime() at the source, i.e. when RisingWave picked
    -- the event up for enrichment. CAVEAT: barrier-aligned, reads up to one
    -- barrier interval EARLY (250ms dev / 1s default) — fine as an "RW is
    -- enriching now" marker, don't trust it below that resolution (broker
    -- time stays available as kafka_timestamp on events_enriched). Compare
    -- against enriched_at stamped by ClickHouse at insert.
    rw_received_at AS rw_enriched_at
FROM events_enriched
WITH (
    connector = 'clickhouse',
    type = 'append-only',
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
