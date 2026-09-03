-- Streaming jobs created below default to ADAPTIVE parallelism (use all
-- cores, rescale automatically on tier changes) instead of being pinned to
-- the core count at creation time. Session-scoped: every file sets it because
-- setup.sh/migrate.sh apply each file in its own psql session.
SET streaming_parallelism = ADAPTIVE;

-- Incrementally-maintained realtime usage for count and sum billable metrics,
-- on 15-minute buckets of the customer-supplied event timestamp.
--
-- This replaces the expire-cache -> recompute-in-ClickHouse loop: buckets are
-- always fresh (duplicate deliveries / re-ingestions are collapsed upstream
-- by the stage-0 dedup, first wins) and are sunk to ClickHouse
-- (06_sinks.sql), where the API sums them over the billing-period window it
-- computes at read time (Subscriptions::DatesService stays the single source
-- of truth for dates — no period rows are maintained anywhere).
--
-- 15 minutes is the granularity that makes any timezone's day boundary land
-- on a bucket wall: every real UTC offset is a multiple of 15 minutes.
-- Known boundary sliver: a period starting mid-bucket (subscription started
-- or terminated mid-day at a non-aligned time) shares its first/last bucket
-- with the neighbour period — at most 15 minutes of events on the first/last
-- day of a subscription.
--
-- One MV serves both current usage and dashboard history (it replaces the
-- former period-keyed usage_realtime and the hourly usage_hourly): history
-- granularities are recomposed by summing buckets. Only count and sum are
-- served because they recompose losslessly across buckets; unique_count does
-- NOT (distinct across buckets != sum of per-bucket distincts) and will need
-- its own structure.
--
-- last_ingested_at is the per-key ingestion watermark: the wallet-trigger
-- consumer waits for ClickHouse to reach it before refreshing (same
-- mechanism as the former Postgres projections), and the usage_latency
-- loopback (07_observability.sql) measures from it.
CREATE MATERIALIZED VIEW IF NOT EXISTS usage_buckets_15m AS
SELECT
    window_start AS bucket,
    organization_id,
    subscription_id,
    customer_id,
    plan_id,
    code,
    target_wallet_code,
    charge_id,
    COALESCE(charge_filter_id, '') AS charge_filter_id,
    -- JSONB is not allowed in a streaming group key; group on its text
    -- rendering instead (cast back with ::jsonb when reading).
    grouped_by::VARCHAR AS grouped_by,
    aggregation_type,
    COUNT(*) AS events_count,
    -- The exponent branch matters: jsonb ->> renders small JSON numbers in
    -- scientific notation (0.000001 -> '1e-6'), which ::DECIMAL parses but a
    -- plain-decimal regex rejects — dropping real units (AggCmp parity run,
    -- 2026-08-31). An exponent outside rw_decimal's 28-digit range makes the
    -- cast error, which streaming evaluates non-strictly to NULL (verified on
    -- '1e999'/'1e-30': job keeps running, SUM skips the row — same result as
    -- ELSE 0, matching the legacy toDecimal-or-zero read).
    SUM(
        CASE WHEN regexp_match(value, '^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$') IS NOT NULL
             THEN value::DECIMAL
             ELSE 0
        END
    ) AS units,
    MAX(event_time) AS last_event_at,
    -- COALESCE: `ingested_at` comes from the event payload and the topic
    -- contract does not guarantee it (the Lago API always sets it —
    -- Events::KafkaProducerService — but a direct producer, a load generator
    -- or a replayed message may not). MAX() already ignores NULLs in a mixed
    -- bucket; without the fallback a bucket where EVERY event lacks it
    -- watermarks NULL, and the ClickHouse column is non-nullable, so the
    -- serving sink dies and takes the whole streaming database into a
    -- recovery loop with it (measured 2026-08-24). event_time is the right
    -- fallback: it is <= the real ingestion time, so the wallet refresh's
    -- `last_ingested_at >= watermark` wait errs toward waiting (bounded),
    -- never toward reading early.
    MAX(COALESCE(ingested_at, event_time)) AS last_ingested_at
FROM TUMBLE(events_expanded, event_time, INTERVAL '15 minutes')
WHERE aggregation_type_code IN (0, 1) -- count, sum
  AND subscription_id IS NOT NULL
  AND charge_id IS NOT NULL
GROUP BY
    window_start, organization_id, subscription_id, customer_id, plan_id,
    code, target_wallet_code, charge_id, COALESCE(charge_filter_id, ''),
    grouped_by::VARCHAR, aggregation_type;
