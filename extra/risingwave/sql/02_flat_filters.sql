-- Rebuild of the Postgres `flat_filters` view (api/db/structure.sql) as a
-- continuously-maintained relation.
--
-- Temporal joins require the right-hand side to be a TABLE (not an MV), so the
-- derived view is computed as an MV and its changelog is landed into a real
-- RisingWave table via CREATE SINK ... INTO (sink-into-table).
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
    -- PK helper: PRIMARY KEY columns cannot be NULL
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

CREATE TABLE IF NOT EXISTS flat_filters (
    organization_id VARCHAR,
    billable_metric_code VARCHAR,
    plan_id VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    charge_filter_id VARCHAR,
    charge_filter_key VARCHAR,
    charge_filter_updated_at TIMESTAMP,
    filters JSONB,
    pricing_group_keys JSONB,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    PRIMARY KEY (charge_id, charge_filter_key)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS flat_filters_load INTO flat_filters AS
SELECT
    organization_id,
    billable_metric_code,
    plan_id,
    charge_id,
    charge_updated_at,
    charge_filter_id,
    charge_filter_key,
    charge_filter_updated_at,
    filters,
    pricing_group_keys,
    pay_in_advance,
    accepts_target_wallet
FROM flat_filters_mv;

-- Index backing the temporal-join lookup from the enrichment view.
CREATE INDEX IF NOT EXISTS idx_flat_filters_lookup
    ON flat_filters (organization_id, plan_id, billable_metric_code);
