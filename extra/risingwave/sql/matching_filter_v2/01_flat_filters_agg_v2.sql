-- matching_filter_v2 evaluation, step 1: the v2 filter dimension.
--
-- NOT applied by setup.sh (it only globs sql/*.sql); apply with
-- sql/matching_filter_v2/apply.sh once the main pipeline is up.
--
-- Same rows as flat_filters_agg (../02_flat_filters.sql), plus two columns
-- computed once per CDC change instead of once per (event, charge):
--   * filters_text: the candidate array as text, the input of
--     matching_filter_v2. Rendering JSONB to text per event is part of what
--     v1 pays; here it happens when the catalog changes.
--   * has_filters: false when the charge has no charge filter at all. The
--     single candidate then has filters = NULL and matching always returns
--     the default bucket, so stage 1 skips the UDF call entirely.
-- filters_agg is kept as JSONB: the stage-1 SQL reads the winner's fields
-- from it natively with filters_agg -> idx.
SET streaming_parallelism = ADAPTIVE;

CREATE MATERIALIZED VIEW IF NOT EXISTS flat_filters_agg_v2_mv AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    has_filters,
    filters_agg,
    filters_agg::varchar AS filters_text
FROM (
    SELECT
        organization_id,
        plan_id,
        billable_metric_code,
        charge_id,
        max(charge_updated_at) AS charge_updated_at,
        bool_or(pay_in_advance) AS pay_in_advance,
        bool_or(accepts_target_wallet) AS accepts_target_wallet,
        -- A charge filter row always has non-empty filters (at worst the
        -- never-matching {"": null}); only the filterless charge's single
        -- row has charge_filter_id NULL and filters NULL.
        bool_or(charge_filter_id IS NOT NULL) AS has_filters,
        -- Must stay identical to flat_filters_agg_mv.filters_agg: element
        -- positions are what matching_filter_v2 returns.
        jsonb_agg(
            jsonb_build_object(
                'charge_filter_id', charge_filter_id,
                'charge_filter_updated_at', charge_filter_updated_at::varchar,
                'filters', filters,
                'pricing_group_keys', pricing_group_keys
            )
            ORDER BY charge_filter_key
        ) AS filters_agg
    FROM flat_filters_mv
    GROUP BY organization_id, plan_id, billable_metric_code, charge_id
) agg;

CREATE TABLE IF NOT EXISTS flat_filters_agg_v2 (
    organization_id VARCHAR,
    plan_id VARCHAR,
    billable_metric_code VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    has_filters BOOLEAN,
    filters_agg JSONB,
    filters_text VARCHAR,
    PRIMARY KEY (organization_id, plan_id, billable_metric_code, charge_id)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS flat_filters_agg_v2_load INTO flat_filters_agg_v2 AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    has_filters,
    filters_agg,
    filters_text
FROM flat_filters_agg_v2_mv;

CREATE INDEX IF NOT EXISTS idx_flat_filters_agg_v2_lookup
    ON flat_filters_agg_v2 (organization_id, plan_id, billable_metric_code)
    DISTRIBUTED BY (organization_id, plan_id, billable_metric_code);
