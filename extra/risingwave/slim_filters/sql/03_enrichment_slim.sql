SET streaming_parallelism = ADAPTIVE;

-- Slim-filters SHADOW of stage 1+2 (../../sql/04_enrichment.sql,
-- events_expanded_load). Reads the same production events_enriched and
-- writes events_expanded_slim, which nothing downstream consumes: it exists
-- to be diffed against events_expanded (parity.sql) and to measure the new
-- filter resolution on real traffic.
--
-- The ONLY semantic change against production is the filter resolution:
--   production: matching_filter(ffc.filters_agg, properties) -> winner JSONB
--               (the whole candidate array crosses into WASM per event)
--   here:       match_filter_position(ffc.match_payload, properties) -> INT
--               then a point lookup in charge_filter_positions on that INT
--               (filters_agg never travels with the event)
-- Everything else (subscription pick, value, grouped_by, clocks) is copied
-- verbatim so a row-level diff isolates the filter resolution.

-- Same columns as events_expanded, same retention.
CREATE TABLE IF NOT EXISTS events_expanded_slim (
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
CREATE SINK IF NOT EXISTS events_expanded_slim_load INTO events_expanded_slim (
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
    LEFT JOIN subscriptions_agg FOR SYSTEM_TIME AS OF PROCTIME() sa
        ON sa.organization_id = e.organization_id
       AND sa.external_id = e.external_subscription_id
    WHERE e.kafka_timestamp >= :'shadow_since'::timestamptz
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
    SELECT
        s.*,
        ffc.charge_id,
        ffc.charge_updated_at,
        ffc.pay_in_advance,
        ffc.accepts_target_wallet,
        ffc.default_pricing_group_keys,
        CASE WHEN ffc.charge_id IS NULL THEN NULL
             ELSE match_filter_position(ffc.match_payload, COALESCE(s.properties, '{}'::jsonb))
        END AS mf_pos
    FROM sub_resolved s
    LEFT JOIN flat_filters_slim FOR SYSTEM_TIME AS OF PROCTIME() ffc
        ON ffc.organization_id = s.organization_id
       AND ffc.plan_id = s.plan_id
       AND ffc.billable_metric_code = s.code
),
resolved AS (
    -- Winner details by point lookup on the returned position. mf_pos = -1
    -- (default bucket) or NULL (no charge) joins nothing: filter identity
    -- reads NULL, and pricing_group_keys falls back to element 0's, which is
    -- ToDefaultFilter. A JSON-null pricing_group_keys behaves like an absent
    -- one through the COALESCE below, as in production.
    SELECT
        c.*,
        cfp.charge_filter_id,
        cfp.charge_filter_updated_at,
        cfp.filters,
        CASE WHEN c.mf_pos >= 0 THEN cfp.pricing_group_keys
             ELSE c.default_pricing_group_keys
        END AS pricing_group_keys
    FROM charged c
    LEFT JOIN charge_filter_positions FOR SYSTEM_TIME AS OF PROCTIME() cfp
        ON cfp.charge_id = c.charge_id
       AND cfp.filter_position = c.mf_pos
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
