SET streaming_parallelism = ADAPTIVE;

-- Stage-1 dimensions for matching_filter v3, built on top of the production
-- flat_filters_agg_mv (../../sql/02_flat_filters.sql): the production chain
-- is read, never modified, and flat_filters_agg feeds the fallback path.
-- Everything here updates on CDC churn only, never per event.
--
-- Instead of scanning a charge's filters per event, each filter is expanded
-- into one lookup key per combination of its allowed values, and an event
-- builds the same key from its properties for each of the charge's shapes
-- (sorted key sets): a filter matches exactly when the keys are equal.
--
--   filter_lookup_charges    one row per charge: its shapes (at most 8) or
--                            the fallback flag, the rank of its filters
--                            without values, and the default bucket's
--                            pricing_group_keys. No filters_agg.
--   filter_lookup            one row per (charge, lookup key): the rank of
--                            the best filter holding that key.
--   filter_lookup_positions  one row per (charge, position in filters_agg):
--                            the winner's details, read by position.
--
-- Selection follows the API's ChargeFilters::EventMatchingService: most keys
-- wins, then the least recently updated filter (ChargeFilter default_scope
-- order, updated_at ASC; the id breaks equal timestamps). A filter without
-- values matches every event with 0 keys. Encoded as one BIGINT per row:
--   rank = key_count * 1e12 + (999999 - api_order) * 1e6 + position
-- position is the 0-based index in filters_agg, read back with rank % 1e6.
-- See udf/src/flv3_common.rs.

CREATE MATERIALIZED VIEW IF NOT EXISTS filter_lookup_charges_mv AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    (lookup_plan ->> 'fallback')::BOOLEAN AS fallback,
    (lookup_plan ->> 'shape_count')::INT AS shape_count,
    lookup_plan -> 'shapes' AS shapes,
    (lookup_plan ->> 'empty_filter_rank')::BIGINT AS empty_filter_rank,
    -- ToDefaultFilter keeps the pricing_group_keys of element 0.
    filters_agg -> 0 -> 'pricing_group_keys' AS default_pricing_group_keys
FROM (
    SELECT *, filter_lookup_plan(filters_agg) AS lookup_plan
    FROM flat_filters_agg_mv
) AS planned;

-- Temporal joins need a TABLE on the right-hand side: same MV -> sink-into-
-- table pattern as flat_filters_agg.
CREATE TABLE IF NOT EXISTS filter_lookup_charges (
    organization_id VARCHAR,
    plan_id VARCHAR,
    billable_metric_code VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    pay_in_advance BOOLEAN,
    accepts_target_wallet BOOLEAN,
    fallback BOOLEAN,
    shape_count INT,
    shapes JSONB,
    empty_filter_rank BIGINT,
    default_pricing_group_keys JSONB,
    PRIMARY KEY (organization_id, plan_id, billable_metric_code, charge_id)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS filter_lookup_charges_load INTO filter_lookup_charges AS
SELECT
    organization_id,
    plan_id,
    billable_metric_code,
    charge_id,
    charge_updated_at,
    pay_in_advance,
    accepts_target_wallet,
    fallback,
    shape_count,
    shapes,
    empty_filter_rank,
    default_pricing_group_keys
FROM filter_lookup_charges_mv;

CREATE INDEX IF NOT EXISTS idx_filter_lookup_charges_lookup
    ON filter_lookup_charges (organization_id, plan_id, billable_metric_code)
    DISTRIBUTED BY (organization_id, plan_id, billable_metric_code);

-- One row per (charge, lookup key). filter_lookup_expand works on the whole
-- array, because a filter's rank depends on its place in the charge's
-- updated_at order, and already keeps the best rank per key, so the key is
-- unique per charge without a GROUP BY. Filters without values have no key
-- (empty_filter_rank above), and filters past the combination cap produce
-- none (their charge is fallback). Fallback charges are expanded too: their
-- rows are never read, and skipping them would mean calling
-- filter_lookup_plan here again.
CREATE MATERIALIZED VIEW IF NOT EXISTS filter_lookup_mv AS
SELECT
    expanded.charge_id,
    k.pair ->> 0 AS lookup_key,
    (k.pair ->> 1)::BIGINT AS rank
FROM (
    SELECT charge_id, filter_lookup_expand(filters_agg) AS pairs
    FROM flat_filters_agg_mv
) AS expanded,
     jsonb_array_elements(expanded.pairs) AS k(pair);

CREATE TABLE IF NOT EXISTS filter_lookup (
    charge_id VARCHAR,
    lookup_key VARCHAR,
    rank BIGINT,
    PRIMARY KEY (charge_id, lookup_key)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS filter_lookup_load INTO filter_lookup AS
SELECT charge_id, lookup_key, rank
FROM filter_lookup_mv;

-- Exploded from the SAME filters_agg array the ranks are computed from, so
-- position N here is position N there by construction. Columns are extracted
-- with the exact expressions production applies to the winner
-- (../../sql/04_enrichment.sql final SELECT), so values are identical.
CREATE MATERIALIZED VIEW IF NOT EXISTS filter_lookup_positions_mv AS
SELECT
    ffa.charge_id,
    (e.ordinality - 1)::INT AS filter_position,
    e.value ->> 'charge_filter_id' AS charge_filter_id,
    (e.value ->> 'charge_filter_updated_at')::timestamp AS charge_filter_updated_at,
    e.value -> 'filters' AS filters,
    e.value -> 'pricing_group_keys' AS pricing_group_keys
FROM flat_filters_agg_mv ffa,
     jsonb_array_elements(ffa.filters_agg) WITH ORDINALITY AS e(value, ordinality);

CREATE TABLE IF NOT EXISTS filter_lookup_positions (
    charge_id VARCHAR,
    filter_position INT,
    charge_filter_id VARCHAR,
    charge_filter_updated_at TIMESTAMP,
    filters JSONB,
    pricing_group_keys JSONB,
    PRIMARY KEY (charge_id, filter_position)
) ON CONFLICT OVERWRITE;

CREATE SINK IF NOT EXISTS filter_lookup_positions_load INTO filter_lookup_positions AS
SELECT
    charge_id,
    filter_position,
    charge_filter_id,
    charge_filter_updated_at,
    filters,
    pricing_group_keys
FROM filter_lookup_positions_mv;
