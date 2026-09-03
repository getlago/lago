-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- DECOUPLED ClickHouse sinks (2026-08-31, after the ClickHouse-outage drill):
-- with sink_decouple=disable, CH sink delivery sits INSIDE the checkpoint, so
-- a dead ClickHouse fails every barrier and meta suspends the WHOLE graph in
-- a hot recovery loop (~2 teardown/rebuilds per second) — wallet triggers and
-- all MVs freeze for the full outage. Decoupled sinks buffer in the log store
-- and stop failing checkpoints, so a CH outage degrades (stale buckets,
-- degraded-stale wallet refreshes) instead of stalling the pipeline.
-- Session-scoped: setup.sh runs each file as its own psql session, so this
-- does NOT leak to the Kafka sinks (07/09) — those keep the system default
-- (disable), which the wallet path's latency depends on.
SET sink_decouple = true;

-- Shadow output: enriched + expanded events, shaped like the production
-- ClickHouse table `events_enriched_expanded`, for parity diffing against the
-- Go processor's output with plain SQL.
--
-- Sinks to ClickHouse, not Kafka (changed 2026-08-24). It previously produced
-- the Go `EnrichedEvent` JSON to an `events_enriched_expanded_shadow` topic,
-- which meant parity diffing had to consume and re-shape a topic. Writing the
-- production table's own shape into a shadow table makes a diff a join, and
-- `enriched_at` (stamped ClickHouse-side at insert) replaces the topic's
-- broker timestamp as the e2e latency endpoint — see 07_observability.sql,
-- whose `pipeline_latency_e2e` loopback MV went away with the topic.
--
-- No force_append_only. The upstream is an APPEND ONLY table read by a
-- projection + filter, so the changelog is insert-only and `type =
-- 'append-only'` binds on its own. Do NOT add it back as belt-and-braces: per
-- ROADMAP §0 it rewrites UpdateInsert into Insert, so it would launder a
-- future retracting operator (a ranking flip) into DUPLICATE rows in a plain
-- MergeTree instead of failing loudly at CREATE SINK.
--
-- CAVEAT on rebuilds: a sink BACKFILLS its upstream snapshot at CREATE time,
-- and the target is a plain MergeTree that counts duplicates. Truncate it
-- (dev) or plan CH-side dedup (prod) before recreating this sink against a
-- populated table — reapply_enrichment.sh warns about the same thing.
--
-- charge_id IS NOT NULL: an event with no charge attribution produces no row
-- in the production expanded table either (it is billable-metric enrichment
-- only), so those rows stay RisingWave-side on `events_expanded`.
--
-- Columns that exist RisingWave-side but NOT in the production table (source,
-- target_wallet_code, filters, pay_in_advance, api_post_processed, recurring,
-- billable_metric_id, customer_id) are deliberately not sunk: query
-- `events_expanded` directly for those.
CREATE SINK IF NOT EXISTS events_enriched_expanded_rw_shadow_sink AS
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
    -- NOTE: unlike the enriched shadow, stage 1+2 does NOT mirror Go's
    -- "<nil>" rendering of a missing property — `value` is NULL there and the
    -- production MV writes it as NULL too, so the shapes already agree.
    value,
    NULLIF(precise_total_amount_cents, '')::DECIMAL AS precise_total_amount_cents,
    -- Production defaults these to '' rather than NULL (an invalid
    -- subscription/plan is an empty string in events_enriched_expanded).
    COALESCE(subscription_id, '') AS subscription_id,
    COALESCE(plan_id, '') AS plan_id,
    charge_id,
    -- Production derives charge_version/charge_filter_version from the same
    -- updated_at values (parseDateTimeBestEffort in events_enriched_expanded_mv).
    charge_updated_at AT TIME ZONE 'UTC' AS charge_version,
    COALESCE(charge_filter_id, '') AS charge_filter_id,
    charge_filter_updated_at AT TIME ZONE 'UTC' AS charge_filter_version,
    aggregation_type,
    COALESCE(grouped_by::VARCHAR, '{}') AS grouped_by_json,
    -- Not part of the production shape; carried so e2e latency
    -- (ingest -> queryable in ClickHouse) is a single query against this table.
    ingested_at AT TIME ZONE 'UTC' AS ingested_at,
    -- RisingWave's stage clocks, so "how long did enrich→expand take, and how
    -- long did the sink take" is answerable in ClickHouse without the load-test
    -- app. Already timestamptz, so no AT TIME ZONE needed.
    rw_received_at AS rw_enriched_at,
    rw_expanded_at
FROM events_expanded
WHERE charge_id IS NOT NULL
WITH (
    connector = 'clickhouse',
    type = 'append-only',
    -- Commit every checkpoint (cloud defaults to every 10) so shadow freshness
    -- stays at the barrier interval.
    commit_checkpoint_interval = 1,
    clickhouse.url = 'http://clickhouse:8123',
    clickhouse.user = 'default',
    clickhouse.password = 'default',
    clickhouse.database = 'default',
    clickhouse.table = 'events_enriched_expanded_rw_shadow'
);

-- Realtime usage buckets -> ClickHouse (API current usage + wallet refresh +
-- dashboard history). Upserts into the ReplacingMergeTree created by
-- clickhouse/usage_buckets_15m.sql; every event updates its bucket row and
-- replaces the row version.
--
-- Quiet-tail latency VALIDATED 2026-08-21 (dev, sink_decouple=disable): a
-- single event with zero follow-up traffic lands in ~335ms; an update to an
-- existing bucket after 60s of total silence lands in ~288ms — the CH upsert
-- sink is NOT in the trailing-flush buffering class that killed the RW-side
-- wallet-trigger refinements.
CREATE SINK IF NOT EXISTS usage_buckets_clickhouse_sink AS
SELECT
    -- event_time is naive UTC; the ClickHouse sink requires timestamptz.
    bucket AT TIME ZONE 'UTC' AS bucket,
    organization_id,
    subscription_id,
    customer_id,
    plan_id,
    code,
    target_wallet_code,
    charge_id,
    charge_filter_id,
    grouped_by,
    aggregation_type,
    events_count,
    units,
    last_event_at AT TIME ZONE 'UTC' AS last_event_at,
    last_ingested_at AT TIME ZONE 'UTC' AS last_ingested_at
FROM usage_buckets_15m
WITH (
    connector = 'clickhouse',
    type = 'upsert',
    primary_key = 'organization_id,subscription_id,charge_id,charge_filter_id,grouped_by,bucket',
    -- Commit every checkpoint (cloud defaults to every 10) so bucket
    -- freshness stays at the barrier interval.
    commit_checkpoint_interval = 1,
    clickhouse.url = 'http://clickhouse:8123',
    clickhouse.user = 'default',
    clickhouse.password = 'default',
    clickhouse.database = 'default',
    clickhouse.table = 'usage_buckets_15m',
    clickhouse.delete.column = 'is_deleted'
);
