-- Serving projection for the API: open billing periods only.
--
-- The temporal filter (now()-based WHERE) automatically retracts rows once a
-- period is 3 days past its end; the Postgres sink propagates those
-- retractions as DELETEs, so usage_realtime_projections in the Lago database
-- stays small — a live cache, not an archive. NULL-period rows (events with
-- no covering billing period) are excluded: they are a monitoring signal,
-- not servable usage.
CREATE MATERIALIZED VIEW IF NOT EXISTS usage_serving AS
SELECT
    subscription_id,
    billing_period_id,
    charge_id,
    COALESCE(charge_filter_id, '') AS charge_filter_id,
    grouped_by,
    organization_id,
    plan_id,
    code,
    aggregation_type,
    period_charges_from,
    period_charges_to,
    events_count,
    units,
    last_event_at,
    last_ingested_at
FROM usage_realtime
WHERE billing_period_id IS NOT NULL
  AND subscription_id IS NOT NULL
  AND period_charges_to AT TIME ZONE 'UTC' >= now() - INTERVAL '3 days';

-- Upserts into the Rails-owned usage_realtime_projections table (created by
-- api migration 20260807173549). The composite primary key must match the
-- table's primary key.
CREATE SINK IF NOT EXISTS usage_projection_pg_sink FROM usage_serving
WITH (
    connector = 'postgres',
    host = 'db',
    port = '5432',
    user = 'lago',
    password = 'changeme',
    database = 'lago',
    table = 'usage_realtime_projections',
    type = 'upsert',
    primary_key = 'subscription_id,billing_period_id,charge_id,charge_filter_id,grouped_by'
);
