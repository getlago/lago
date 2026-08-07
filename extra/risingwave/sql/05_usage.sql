-- Incrementally-maintained realtime usage for count and sum billable metrics.
--
-- This is the view that replaces the expire-cache -> recompute-in-ClickHouse
-- loop for count/sum: it is always fresh, and duplicate deliveries /
-- reprocessed events are corrected upstream by the dedup stage.
--
-- Keyed by billing period (Rails-maintained subscription_billing_periods via
-- CDC + temporal join): one row per (subscription, charge, filter, grouped_by,
-- period). Events without a covering period land on a NULL period key —
-- monitor those, they indicate a gap in the period-maintenance clock job.
CREATE MATERIALIZED VIEW IF NOT EXISTS usage_realtime AS
SELECT
    organization_id,
    subscription_id,
    plan_id,
    billing_period_id,
    period_charges_from,
    period_charges_to,
    code,
    charge_id,
    charge_filter_id,
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
    -- Feeds the usage_latency loopback (07_observability.sql).
    MAX(ingested_at) AS last_ingested_at
FROM events_expanded
WHERE aggregation_type_code IN (0, 1) -- count, sum
  AND subscription_id IS NOT NULL
  AND charge_id IS NOT NULL
GROUP BY
    organization_id, subscription_id, plan_id,
    billing_period_id, period_charges_from, period_charges_to, code,
    charge_id, charge_filter_id, grouped_by::VARCHAR, aggregation_type;

-- Hourly usage time-series per charge/filter, keyed on the customer-supplied
-- event timestamp (late/backfilled events land in the hour the customer
-- expects). Sits downstream of dedup, so corrections update the affected
-- hour. Sunk to ClickHouse (06_sinks.sql) which serves dashboard history;
-- RisingWave only needs to retain recent window state.
CREATE MATERIALIZED VIEW IF NOT EXISTS usage_hourly AS
SELECT
    window_start AS hour,
    organization_id,
    subscription_id,
    plan_id,
    code,
    charge_id,
    COALESCE(charge_filter_id, '') AS charge_filter_id,
    grouped_by::VARCHAR AS grouped_by,
    aggregation_type,
    COUNT(*) AS events_count,
    SUM(
        CASE WHEN regexp_match(value, '^-?[0-9]+(\.[0-9]+)?$') IS NOT NULL
             THEN value::DECIMAL
             ELSE 0
        END
    ) AS units
FROM TUMBLE(events_expanded, event_time, INTERVAL '1 hour')
WHERE aggregation_type_code IN (0, 1) -- count, sum
  AND subscription_id IS NOT NULL
  AND charge_id IS NOT NULL
GROUP BY
    window_start, organization_id, subscription_id, plan_id, code,
    charge_id, COALESCE(charge_filter_id, ''), grouped_by::VARCHAR, aggregation_type;
