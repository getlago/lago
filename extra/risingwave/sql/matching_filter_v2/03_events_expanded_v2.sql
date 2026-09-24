-- matching_filter_v2 evaluation, step 3 (optional): a SHADOW of stage 1+2.
--
-- NOT applied by setup.sh; apply with sql/matching_filter_v2/apply.sh.
--
-- events_expanded_v2 is fed by the same query as events_expanded_load
-- (../04_enrichment.sql) except for the filter resolution, so the two tables
-- can be compared row for row (04_parity_check.sql). It reads the same
-- events_enriched stream, so it roughly DOUBLES stage-1 work while it runs,
-- and creating it BACKFILLS the whole events_enriched retention window
-- (~33 days) into events_expanded_v2. Drop it (apply.sh --drop) once the
-- comparison is done.
--
-- Differences from events_expanded_load:
--   * flat_filters_agg_v2 instead of flat_filters_agg (01_flat_filters_agg_v2.sql).
--   * matching_filter_v2(filters_text, properties) returns the winner's
--     position; the winner's fields are read natively from filters_agg.
--     -1 is the default bucket: no filter identity, pricing_group_keys from
--     element 0 (v1's to_default_filter(filters[0])).
--     Careful: filters_agg -> -1 would be the LAST element, hence the CASE.
--   * No UDF call for charges without filters (has_filters = false): the
--     only candidate has no filters, so the answer is always the default
--     bucket.
--   * No extract_grouped_by call when there is nothing to group by: no
--     pricing_group_keys array (or an empty one) and no target wallet. v1
--     returns '{}' in that case.
SET streaming_parallelism = ADAPTIVE;

CREATE TABLE IF NOT EXISTS events_expanded_v2 (
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
    -- Clocks carried through from stage 0, so the expanded row alone can account
    -- for its own latency: broker append time and the source pickup proctime.
    kafka_timestamp TIMESTAMPTZ,
    rw_received_at TIMESTAMPTZ,
    -- Stage-1+2 stamp, and the reason the sink below lists its target columns
    -- explicitly: the sink does NOT write this one, so the DEFAULT applies at
    -- insert and records when stage 1 actually emitted the row.
    --
    -- It has to be a column DEFAULT. `proctime()` is rejected outside
    -- CREATE TABLE/SOURCE, and a bare `now()` in a streaming projection is
    -- rejected too ("only allowed in WHERE, HAVING, ON and FROM") — a table
    -- default is the one position where RisingWave will evaluate it per row.
    --
    -- CAVEAT, same class as rw_received_at: now() is the BARRIER timestamp, so
    -- rows emitted in one barrier share a stamp and the resolution is
    -- barrier_interval_ms (250ms dev / 1s default). Do not read it below that.
    rw_expanded_at TIMESTAMPTZ DEFAULT now()
) APPEND ONLY WITH (retention_seconds = 2851200); -- 33 days

CREATE SINK IF NOT EXISTS events_expanded_v2_load INTO events_expanded_v2 (
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
    SELECT
        s.*,
        ffc.charge_id,
        ffc.charge_updated_at,
        ffc.pay_in_advance,
        ffc.accepts_target_wallet,
        ffc.filters_agg,
        CASE WHEN ffc.charge_id IS NULL THEN NULL
             WHEN NOT ffc.has_filters THEN -1
             ELSE matching_filter_v2(ffc.filters_text, COALESCE(s.properties, '{}'::jsonb))
        END AS mf_idx
    FROM sub_resolved s
    BROADCAST LEFT JOIN flat_filters_agg_v2 FOR SYSTEM_TIME AS OF PROCTIME() ffc
        ON ffc.organization_id = s.organization_id
       AND ffc.plan_id = s.plan_id
       AND ffc.billable_metric_code = s.code
),
resolved AS (
    SELECT
        *,
        -- The winning candidate, NULL for the default bucket (and for
        -- charge-less rows), like v1's mf without filter identity.
        CASE WHEN mf_idx >= 0 THEN filters_agg -> mf_idx END AS mf,
        CASE WHEN mf_idx >= 0 THEN filters_agg -> mf_idx
             WHEN mf_idx = -1 THEN filters_agg -> 0
        END -> 'pricing_group_keys' AS mf_pricing_group_keys
    FROM charged
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
    mf ->> 'charge_filter_id' AS charge_filter_id,
    (mf ->> 'charge_filter_updated_at')::timestamp AS charge_filter_updated_at,
    mf -> 'filters' AS filters,
    pay_in_advance,
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE properties ->> field_name
    END AS value,
    CASE WHEN NOT COALESCE(accepts_target_wallet, false)
          AND (mf_pricing_group_keys IS NULL
               OR jsonb_typeof(mf_pricing_group_keys) <> 'array'
               OR jsonb_array_length(mf_pricing_group_keys) = 0)
         THEN '{}'::jsonb
         ELSE extract_grouped_by(
             COALESCE(mf_pricing_group_keys, 'null'::jsonb),
             COALESCE(properties, '{}'::jsonb),
             COALESCE(accepts_target_wallet, false)
         )
    END AS grouped_by,
    CASE WHEN COALESCE(accepts_target_wallet, false) THEN properties ->> 'target_wallet_code' END AS target_wallet_code,
    kafka_timestamp,
    rw_received_at
FROM resolved
WITH (type = 'append-only', force_append_only = 'true');
