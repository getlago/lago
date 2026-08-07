-- Incrementally-maintained realtime usage for count and sum billable metrics.
--
-- This is the view that replaces the expire-cache -> recompute-in-ClickHouse
-- loop for count/sum: it is always fresh, and duplicate deliveries /
-- reprocessed events are corrected upstream by the dedup stage.
--
-- Phase 2: key by billing period (Rails-maintained current_billing_periods
-- table via CDC + temporal join). Until then this aggregates all events seen
-- by the pipeline since it started.
CREATE MATERIALIZED VIEW IF NOT EXISTS usage_realtime AS
SELECT
    organization_id,
    subscription_id,
    plan_id,
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
    organization_id, subscription_id, plan_id, code,
    charge_id, charge_filter_id, grouped_by::VARCHAR, aggregation_type;
