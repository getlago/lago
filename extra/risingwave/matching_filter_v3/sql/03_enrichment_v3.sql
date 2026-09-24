SET streaming_parallelism = ADAPTIVE;

-- matching_filter v3 SHADOW of stage 1+2 (../../sql/04_enrichment.sql,
-- events_expanded_load). Reads the same production events_enriched and
-- writes events_expanded_v3, which nothing downstream consumes: it exists to
-- be diffed against events_expanded (../parity.sh) and to measure the lookup
-- resolution on real traffic.
--
-- The ONLY semantic change against production is how the filter is found:
--   production: matching_filter(ffc.filters_agg, properties) -> winner JSONB
--               (the whole candidate array crosses into WASM per event)
--   here:       filter_lookup_event_keys(shapes, properties) -> one key per
--               shape, one point lookup per shape slot in filter_lookup,
--               GREATEST(rank) -> winner position -> point lookup of its
--               details in filter_lookup_positions.
--   fallback:   charges with more than 8 shapes (or an oversized filter) run
--               the production matching_filter on flat_filters_agg, joined
--               on a key that is NULL for every other charge.
-- Everything else (subscription pick, value, grouped_by, clocks) is copied
-- verbatim so a row-level diff isolates the filter resolution.

-- Same columns as events_expanded, same retention.
CREATE TABLE IF NOT EXISTS events_expanded_v3 (
    organization_id VARCHAR,
    external_subscription_id VARCHAR,
    transaction_id VARCHAR,
    code VARCHAR,
    properties JSONB,
    precise_total_amount_cents VARCHAR,
    source VARCHAR,
    event_ts DOUBLE PRECISION,
    event_time TIMESTAMP,
    ingested_at TIMESTAMP,
    api_post_processed BOOLEAN,
    billable_metric_id VARCHAR,
    aggregation_type_code INT,
    aggregation_type VARCHAR,
    recurring BOOLEAN,
    subscription_id VARCHAR,
    customer_id VARCHAR,
    plan_id VARCHAR,
    charge_id VARCHAR,
    charge_updated_at TIMESTAMP,
    charge_filter_id VARCHAR,
    charge_filter_updated_at TIMESTAMP,
    filters JSONB,
    pay_in_advance BOOLEAN,
    value VARCHAR,
    grouped_by JSONB,
    target_wallet_code VARCHAR,
    kafka_timestamp TIMESTAMPTZ,
    rw_received_at TIMESTAMPTZ,
    rw_expanded_at TIMESTAMPTZ DEFAULT now()
) APPEND ONLY WITH (retention_seconds = 2851200); -- 33 days

-- Start point: :'shadow_since' (psql variable, set by setup.sh from
-- SHADOW_SINCE, default = apply time). A sink-into-table backfills its whole
-- upstream and RisingWave 3.0.2 rejects `snapshot = 'false'` on a sink with a
-- query, so the backfill is cut by this constant filter instead: older
-- events_enriched rows are scanned but dropped before any join or UDF.
-- Set SHADOW_SINCE in the past to get history to compare right away.
CREATE SINK IF NOT EXISTS events_expanded_v3_load INTO events_expanded_v3 (
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    aggregation_type,
    recurring,
    subscription_id,
    customer_id,
    plan_id,
    charge_id,
    charge_updated_at,
    charge_filter_id,
    charge_filter_updated_at,
    filters,
    pay_in_advance,
    value,
    grouped_by,
    target_wallet_code,
    kafka_timestamp,
    rw_received_at
) AS
WITH sub_picked AS (
    SELECT
        e.*,
        pick_subscription(sa.subs, e.event_ts) AS picked_sub
    FROM events_enriched e
    BROADCAST LEFT JOIN subscriptions_agg FOR SYSTEM_TIME AS OF PROCTIME() sa
        ON sa.organization_id = e.organization_id
       AND sa.external_id = e.external_subscription_id
),
sub_resolved AS (
    SELECT
        *,
        picked_sub ->> 'id' AS subscription_id,
        picked_sub ->> 'customer_id' AS customer_id,
        picked_sub ->> 'plan_id' AS plan_id
    FROM sub_picked
),
charged AS (
    -- One row per charge of (org, plan, code), like production. The event
    -- keys are only built for lookup charges that have at least one shape:
    -- a filterless charge goes straight to the default bucket.
    SELECT
        s.*,
        flc.charge_id,
        flc.charge_updated_at,
        flc.pay_in_advance,
        flc.accepts_target_wallet,
        flc.default_pricing_group_keys,
        flc.fallback,
        CASE WHEN flc.charge_id IS NOT NULL AND NOT flc.fallback AND flc.shape_count > 0
             THEN filter_lookup_event_keys(flc.shapes, COALESCE(s.properties, '{}'::jsonb))
        END AS lookup_keys
    FROM sub_resolved s
    BROADCAST LEFT JOIN filter_lookup_charges FOR SYSTEM_TIME AS OF PROCTIME() flc
        ON flc.organization_id = s.organization_id
       AND flc.plan_id = s.plan_id
       AND flc.billable_metric_code = s.code
),
keyed AS (
    -- Slot i = shape i. "" (shape does not apply) and missing slots (fewer
    -- shapes than slots, out-of-range index) become NULL and join nothing.
    -- The 8 slots MUST match FLV3_SHAPE_SLOTS (udf/src/flv3_common.rs).
    SELECT
        *,
        NULLIF(lookup_keys[1], '') AS k1,
        NULLIF(lookup_keys[2], '') AS k2,
        NULLIF(lookup_keys[3], '') AS k3,
        NULLIF(lookup_keys[4], '') AS k4,
        NULLIF(lookup_keys[5], '') AS k5,
        NULLIF(lookup_keys[6], '') AS k6,
        NULLIF(lookup_keys[7], '') AS k7,
        NULLIF(lookup_keys[8], '') AS k8,
        CASE WHEN fallback THEN charge_id END AS fallback_charge_id
    FROM charged
),
looked_up AS (
    -- Stateless chain of left temporal joins (an append-only LHS keeps no
    -- state). Each finds at most one row; GREATEST ignores the NULLs.
    SELECT
        k.*,
        GREATEST(l1.rank, l2.rank, l3.rank, l4.rank, l5.rank, l6.rank, l7.rank, l8.rank) AS best_rank,
        CASE WHEN ffa.charge_id IS NOT NULL
             THEN matching_filter(ffa.filters_agg, COALESCE(k.properties, '{}'::jsonb))
        END AS mf
    FROM keyed k
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l1
        ON l1.charge_id = k.charge_id AND l1.lookup_key = k.k1
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l2
        ON l2.charge_id = k.charge_id AND l2.lookup_key = k.k2
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l3
        ON l3.charge_id = k.charge_id AND l3.lookup_key = k.k3
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l4
        ON l4.charge_id = k.charge_id AND l4.lookup_key = k.k4
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l5
        ON l5.charge_id = k.charge_id AND l5.lookup_key = k.k5
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l6
        ON l6.charge_id = k.charge_id AND l6.lookup_key = k.k6
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l7
        ON l7.charge_id = k.charge_id AND l7.lookup_key = k.k7
    BROADCAST LEFT JOIN filter_lookup FOR SYSTEM_TIME AS OF PROCTIME() l8
        ON l8.charge_id = k.charge_id AND l8.lookup_key = k.k8
    -- Fallback: the production path, on the production table.
    BROADCAST LEFT JOIN flat_filters_agg FOR SYSTEM_TIME AS OF PROCTIME() ffa
        ON ffa.organization_id = k.organization_id
       AND ffa.plan_id = k.plan_id
       AND ffa.billable_metric_code = k.code
       AND ffa.charge_id = k.fallback_charge_id
),
positioned AS (
    -- Rank -> position (02_lookup.sql). No hit -> -1, the default bucket.
    -- NULL for charge-less rows and fallback charges.
    SELECT
        *,
        CASE WHEN charge_id IS NULL OR fallback THEN NULL
             WHEN best_rank IS NULL THEN -1
             ELSE (999999999 - best_rank % 1000000000)::INT
        END AS mf_pos
    FROM looked_up
),
resolved AS (
    -- Winner details by point lookup on the position (mf_pos = -1 or NULL
    -- joins nothing). Default bucket: filter identity NULL, pricing_group_keys
    -- from element 0, which is ToDefaultFilter. Fallback: the production mf.
    SELECT
        c.*,
        CASE WHEN c.fallback THEN c.mf ->> 'charge_filter_id'
             ELSE p.charge_filter_id
        END AS charge_filter_id,
        CASE WHEN c.fallback THEN (c.mf ->> 'charge_filter_updated_at')::timestamp
             ELSE p.charge_filter_updated_at
        END AS charge_filter_updated_at,
        CASE WHEN c.fallback THEN c.mf -> 'filters'
             ELSE p.filters
        END AS filters,
        CASE WHEN c.fallback THEN c.mf -> 'pricing_group_keys'
             WHEN c.mf_pos >= 0 THEN p.pricing_group_keys
             ELSE c.default_pricing_group_keys
        END AS pricing_group_keys
    FROM positioned c
    BROADCAST LEFT JOIN filter_lookup_positions FOR SYSTEM_TIME AS OF PROCTIME() p
        ON p.charge_id = c.charge_id
       AND p.filter_position = c.mf_pos
)
SELECT
    organization_id,
    external_subscription_id,
    transaction_id,
    code,
    properties,
    precise_total_amount_cents,
    source,
    event_ts,
    event_time,
    ingested_at,
    api_post_processed,
    billable_metric_id,
    aggregation_type_code,
    CASE aggregation_type_code
        WHEN 0 THEN 'count'
        WHEN 1 THEN 'sum'
        WHEN 2 THEN 'max'
        WHEN 3 THEN 'unique_count'
        WHEN 5 THEN 'weighted_sum'
        WHEN 6 THEN 'latest'
        WHEN 7 THEN 'custom'
        ELSE ''
    END AS aggregation_type,
    recurring,
    subscription_id,
    customer_id,
    plan_id,
    charge_id,
    charge_updated_at,
    charge_filter_id,
    charge_filter_updated_at,
    filters,
    pay_in_advance,
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE properties ->> field_name
    END AS value,
    extract_grouped_by(
        COALESCE(pricing_group_keys, 'null'::jsonb),
        COALESCE(properties, '{}'::jsonb),
        COALESCE(accepts_target_wallet, false)
    ) AS grouped_by,
    CASE WHEN COALESCE(accepts_target_wallet, false) THEN properties ->> 'target_wallet_code' END AS target_wallet_code,
    kafka_timestamp,
    rw_received_at
FROM resolved
WITH (type = 'append-only', force_append_only = 'true');
