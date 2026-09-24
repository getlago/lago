SET streaming_parallelism = ADAPTIVE;

-- Stage-1 dimensions for the slim-filters shadow, built on top of the
-- production flat_filters_agg_mv (../../sql/02_flat_filters.sql): the
-- production chain is read, never modified. Everything here updates on CDC
-- churn only, never per event.
--
-- Two lookups replace the single flat_filters_agg row:
--   flat_filters_slim        one row per charge, WITHOUT filters_agg: the
--                            compact match_payload scanned per event by
--                            match_filter_position, plus the default bucket's
--                            pricing_group_keys.
--   charge_filter_positions  one row per (charge, position in filters_agg):
--                            the winner's details, fetched by a point lookup
--                            on the position the UDF returns.
-- Measured on a 2502-filter charge (README): passing filters_agg into a UDF
-- costs ~3.7ms per call and dominates matching_filter (~3.85ms); reading the
-- winner back with `filters_agg -> position` still costs ~0.5ms because the
-- 556KB column travels with every row. Hence neither lookup carries it.

CREATE MATERIALIZED VIEW IF NOT EXISTS flat_filters_slim_mv AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    encode_filter_payload(filters_agg) AS match_payload,
    -- ToDefaultFilter keeps the pricing_group_keys of element 0.
    filters_agg -> 0 -> 'pricing_group_keys' AS default_pricing_group_keys
FROM flat_filters_agg_mv;

-- Temporal joins need a TABLE on the right-hand side: same MV -> sink-into-
-- table pattern as flat_filters_agg.
CREATE TABLE IF NOT EXISTS flat_filters_slim (
    organization_id VARCHAR,
    plan_id VARCHAR,
    billable_metric_code VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    match_payload VARCHAR,
    default_pricing_group_keys JSONB,
    PRIMARY KEY (organization_id, plan_id, billable_metric_code, charge_id)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS flat_filters_slim_load INTO flat_filters_slim AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    match_payload,
    default_pricing_group_keys
FROM flat_filters_slim_mv;

CREATE INDEX IF NOT EXISTS idx_flat_filters_slim_lookup
    ON flat_filters_slim (organization_id, plan_id, billable_metric_code)
    DISTRIBUTED BY (organization_id, plan_id, billable_metric_code);

-- Exploded from the SAME filters_agg array the payload is encoded from, so
-- position N here is position N in the payload by construction. Columns are
-- extracted with the exact expressions production applies to the winner
-- (../../sql/04_enrichment.sql final SELECT), so values are identical.
CREATE MATERIALIZED VIEW IF NOT EXISTS charge_filter_positions_mv AS
SELECT
    ffa.charge_id,
    (e.ordinality - 1)::INT AS filter_position,
    e.value ->> 'charge_filter_id' AS charge_filter_id,
    (e.value ->> 'charge_filter_updated_at')::timestamp AS charge_filter_updated_at,
    e.value -> 'filters' AS filters,
    e.value -> 'pricing_group_keys' AS pricing_group_keys
FROM flat_filters_agg_mv ffa,
     jsonb_array_elements(ffa.filters_agg) WITH ORDINALITY AS e(value, ordinality);

CREATE TABLE IF NOT EXISTS charge_filter_positions (
    charge_id VARCHAR,
    filter_position INT,
    charge_filter_id VARCHAR,
    charge_filter_updated_at TIMESTAMP,
    filters JSONB,
    pricing_group_keys JSONB,
    PRIMARY KEY (charge_id, filter_position)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS charge_filter_positions_load INTO charge_filter_positions AS
SELECT
    charge_id,
    filter_position,
    charge_filter_id,
    charge_filter_updated_at,
    filters,
    pricing_group_keys
FROM charge_filter_positions_mv;
