-- Dimension derivations for stage-1 enrichment.
--
-- Part 1 rebuilds the Postgres `flat_filters` view (api/db/structure.sql) as
-- a continuously-maintained MV. Part 2 (2026-08-28 redesign, ROADMAP §0c)
-- aggregates the lookup dimensions into per-key JSONB ARRAYS: each charge's
-- candidate filters and each external_id's subscriptions become ONE row, so
-- stage 1 temporal-joins exactly one row per lookup and resolves the
-- candidate set with a scalar UDF looping in memory — the way the Go
-- processor loops over its cache — instead of materializing the join fan-out
-- as per-event ranking state synced to object storage every barrier (the
-- proven ~3k ev/s ceiling on staging).
--
-- Temporal joins require the right-hand side to be a TABLE (not an MV), so
-- each derived view is computed as an MV and its changelog is landed into a
-- real RisingWave table via CREATE SINK ... INTO (sink-into-table). These
-- tables hold DIMENSION state only — they grow with the catalog (charges,
-- subscriptions), not with event volume, and update only on CDC churn.
--
-- The filter-values aggregation is done in its own view keyed by
-- charge_filter_id, so no JSONB column ends up in a streaming group key.
CREATE MATERIALIZED VIEW IF NOT EXISTS charge_filter_values_agg AS
SELECT
    cfv.charge_filter_id,
    jsonb_object_agg(
        COALESCE(bmf.key, ''),
        to_jsonb(
            CASE WHEN array_position(cfv."values", '__ALL_FILTER_VALUES__') IS NOT NULL
                 THEN bmf."values"
                 ELSE cfv."values"
            END
        )
    ) AS filters
FROM charge_filter_values cfv
LEFT JOIN billable_metric_filters bmf
    ON bmf.id = cfv.billable_metric_filter_id AND bmf.deleted_at IS NULL
WHERE cfv.deleted_at IS NULL
GROUP BY cfv.charge_filter_id;

CREATE MATERIALIZED VIEW IF NOT EXISTS flat_filters_mv AS
SELECT
    bm.organization_id,
    bm.code AS billable_metric_code,
    c.plan_id,
    c.id AS charge_id,
    c.updated_at AS charge_updated_at,
    cf.id AS charge_filter_id,
    -- Deterministic per-charge candidate order (the Go processor's slice
    -- order is unspecified DB row order; matching_filter reads element 0 for
    -- the default bucket, so the order must be stable here).
    COALESCE(cf.id, 'default') AS charge_filter_key,
    cf.updated_at AS charge_filter_updated_at,
    -- A charge filter without any values still counts as a (never-matching)
    -- filter, like in the Postgres view: {"": null}.
    CASE WHEN cf.id IS NOT NULL
         THEN COALESCE(fva.filters, '{"": null}'::jsonb)
         ELSE NULL
    END AS filters,
    (COALESCE(cf.properties, c.properties) -> 'pricing_group_keys') AS pricing_group_keys,
    c.pay_in_advance,
    c.accepts_target_wallet
FROM billable_metrics bm
JOIN charges c ON c.billable_metric_id = bm.id
LEFT JOIN charge_filters cf
    ON cf.charge_id = c.id AND cf.deleted_at IS NULL
LEFT JOIN charge_filter_values_agg fva
    ON fva.charge_filter_id = cf.id
WHERE bm.deleted_at IS NULL AND c.deleted_at IS NULL;

-- One row per charge reachable from (org, plan, code): the charge's
-- flat_filters rows as a JSONB array in charge_filter_key order, consumed by
-- matching_filter() (a port of Go's MatchingFilter — see 03_functions.sql).
-- charge_filter_updated_at is stringified because RisingWave renders
-- timestamps into jsonb in ISO-T form; ::varchar keeps the 'YYYY-MM-DD
-- HH:MM:SS.ffffff' shape that the ::timestamp cast in 04_enrichment.sql
-- parses back losslessly.
CREATE MATERIALIZED VIEW IF NOT EXISTS flat_filters_agg_mv AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    -- charge-level attributes: constant across the charge's filter rows
    max(charge_updated_at) AS charge_updated_at,
    bool_or(pay_in_advance) AS pay_in_advance,
    bool_or(accepts_target_wallet) AS accepts_target_wallet,
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
GROUP BY organization_id, plan_id, billable_metric_code, charge_id;

CREATE TABLE IF NOT EXISTS flat_filters_agg (
    organization_id VARCHAR,
    plan_id VARCHAR,
    billable_metric_code VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    filters_agg JSONB,
    PRIMARY KEY (organization_id, plan_id, billable_metric_code, charge_id)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS flat_filters_agg_load INTO flat_filters_agg AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    filters_agg
FROM flat_filters_agg_mv;

-- Index backing the stage-1 temporal-join lookup (an event knows org, plan
-- and code; the join fans out one row per charge).
CREATE INDEX IF NOT EXISTS idx_flat_filters_agg_lookup
    ON flat_filters_agg (organization_id, plan_id, billable_metric_code);

-- One row per (org, external_id): every subscription row of the external_id
-- as a JSONB array, consumed by pick_subscription() (a port of Go's
-- FetchSubscription — see 03_functions.sql). Timestamps are pre-floored to
-- epoch milliseconds, mirroring Go's date_trunc('millisecond', ...) on both
-- bounds; the raw event timestamp stays untruncated, like Go's `?::timestamp`
-- parameter. Element order is id ASC — pick_subscription re-orders anyway,
-- deterministic input keeps the relation canonical.
CREATE MATERIALIZED VIEW IF NOT EXISTS subscriptions_agg_mv AS
SELECT
    organization_id,
    external_id,
    jsonb_agg(
        jsonb_build_object(
            'id', id,
            'customer_id', customer_id,
            'plan_id', plan_id,
            'started_at_ms', (floor(extract(epoch FROM started_at) * 1000))::bigint,
            'terminated_at_ms', (floor(extract(epoch FROM terminated_at) * 1000))::bigint
        )
        ORDER BY id
    ) AS subs
FROM subscriptions
GROUP BY organization_id, external_id;

CREATE TABLE IF NOT EXISTS subscriptions_agg (
    organization_id VARCHAR,
    external_id VARCHAR,
    subs JSONB,
    PRIMARY KEY (organization_id, external_id)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS subscriptions_agg_load INTO subscriptions_agg AS
SELECT
    organization_id,
    external_id,
    subs
FROM subscriptions_agg_mv;
