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
    SUM(
        CASE WHEN regexp_match(value, '^-?[0-9]+(\.[0-9]+)?$') IS NOT NULL
             THEN value::DECIMAL
             ELSE 0
        END
    ) AS units,
    MAX(event_time) AS last_event_at,
    MAX(ingested_at) AS last_ingested_at
FROM TUMBLE(events_expanded, event_time, INTERVAL '15 minutes')
WHERE aggregation_type_code IN (0, 1) -- count, sum
  AND subscription_id IS NOT NULL
  AND charge_id IS NOT NULL
GROUP BY
    window_start, organization_id, subscription_id, customer_id, plan_id,
    code, target_wallet_code, charge_id, COALESCE(charge_filter_id, ''),
    grouped_by::VARCHAR, aggregation_type;
