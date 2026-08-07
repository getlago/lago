-- Stage 1: temporal joins only (append-only in, append-only out).
--
-- All lookups happen here, against the *current* state of the CDC tables at
-- event arrival time (same semantics as the Go processor reading its cache).
-- Ranking/dedup happens in stage 2, because temporal joins require an
-- append-only left side.
--
-- The LEFT joins deliberately match on equality keys only; time-window
-- validity (subscription active / billing period covering the event
-- timestamp) is computed as flags and resolved by ranking in stage 2.
CREATE MATERIALIZED VIEW IF NOT EXISTS events_joined AS
SELECT
    e.organization_id,
    e.external_subscription_id,
    e.transaction_id,
    e.code,
    e.properties,
    e.precise_total_amount_cents,
    e.source,
    e."timestamp"::DOUBLE PRECISION AS event_ts,
    to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC' AS event_time,
    e.ingested_at,
    COALESCE((e.source_metadata).api_post_processed, false) AS api_post_processed,
    COALESCE((e.source_metadata).reprocess, false) AS reprocess,
    bm.id AS billable_metric_id,
    bm.aggregation_type AS aggregation_type_code,
    bm.field_name,
    bm.expression,
    bm.recurring,
    s.id AS subscription_id,
    s.customer_id AS subscription_customer_id,
    s.plan_id AS subscription_plan_id,
    s.started_at AS subscription_started_at,
    s.terminated_at AS subscription_terminated_at,
    (
        s.id IS NOT NULL
        AND s.started_at <= to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC'
        AND (
            s.terminated_at IS NULL
            OR s.terminated_at >= to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC'
        )
    ) AS subscription_valid,
    bp.id AS billing_period_id,
    bp.charges_from AS period_charges_from,
    bp.charges_to AS period_charges_to,
    (
        bp.id IS NOT NULL
        AND bp.charges_from <= to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC'
        AND bp.charges_to >= to_timestamp(e."timestamp"::DOUBLE PRECISION) AT TIME ZONE 'UTC'
    ) AS period_valid,
    ff.charge_id,
    ff.charge_updated_at,
    ff.charge_filter_id,
    ff.charge_filter_key,
    ff.charge_filter_updated_at,
    ff.filters,
    ff.pricing_group_keys,
    ff.pay_in_advance,
    ff.accepts_target_wallet,
    CASE WHEN ff.charge_id IS NULL THEN NULL
         ELSE filter_match_score(ff.filters, e.properties)
    END AS match_score
FROM events_raw e
JOIN billable_metrics FOR SYSTEM_TIME AS OF PROCTIME() bm
    ON bm.organization_id = e.organization_id
   AND bm.code = e.code
   AND bm.deleted_at IS NULL
LEFT JOIN subscriptions FOR SYSTEM_TIME AS OF PROCTIME() s
    ON s.organization_id = e.organization_id
   AND s.external_id = e.external_subscription_id
LEFT JOIN subscription_billing_periods FOR SYSTEM_TIME AS OF PROCTIME() bp
    ON bp.subscription_id = s.id
LEFT JOIN flat_filters FOR SYSTEM_TIME AS OF PROCTIME() ff
    ON ff.organization_id = e.organization_id
   AND ff.plan_id = s.plan_id
   AND ff.billable_metric_code = e.code;

-- Stage 2: pick the best subscription + covering billing period per event,
-- the best-matching filter per (event, charge) with default-bucket fallback,
-- then keep only the latest delivery per (event, charge) — duplicate
-- deliveries are no-ops and reprocessed events become corrections that flow
-- into the aggregates.
--
-- The DENSE_RANK ordering fully determines a (subscription, billing period)
-- pair, so rank 1 keeps exactly the filter fan-out rows of the best pair:
-- valid subscription first, then valid (covering) period, most recent as
-- tie-breakers.
CREATE MATERIALIZED VIEW IF NOT EXISTS events_expanded AS
WITH best_sub AS (
    SELECT * FROM (
        SELECT
            *,
            DENSE_RANK() OVER (
                PARTITION BY organization_id, transaction_id, ingested_at
                ORDER BY
                    subscription_valid DESC,
                    subscription_terminated_at DESC NULLS FIRST,
                    subscription_started_at DESC,
                    subscription_id,
                    period_valid DESC,
                    period_charges_from DESC NULLS LAST,
                    billing_period_id
            ) AS sub_rank
        FROM events_joined
    ) ranked_subs
    WHERE sub_rank = 1
),
best_filter AS (
    SELECT * FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY organization_id, transaction_id, ingested_at, COALESCE(charge_id, '')
                ORDER BY match_score DESC, charge_filter_key
            ) AS filter_rank
        FROM best_sub
    ) ranked_filters
    WHERE filter_rank = 1
),
latest_delivery AS (
    SELECT * FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY organization_id, transaction_id, COALESCE(charge_id, '')
                ORDER BY ingested_at DESC
            ) AS delivery_rank
        FROM best_filter
    ) ranked_deliveries
    WHERE delivery_rank = 1
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
    reprocess,
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
    CASE WHEN subscription_valid THEN subscription_id END AS subscription_id,
    CASE WHEN subscription_valid THEN subscription_customer_id END AS customer_id,
    CASE WHEN subscription_valid THEN subscription_plan_id END AS plan_id,
    CASE WHEN period_valid THEN billing_period_id END AS billing_period_id,
    CASE WHEN period_valid THEN period_charges_from END AS period_charges_from,
    CASE WHEN period_valid THEN period_charges_to END AS period_charges_to,
    charge_id,
    charge_updated_at,
    -- Default bucket: best candidate did not match -> attribute to the charge
    -- itself, without a filter (mirrors MatchingFilter/ToDefaultFilter).
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN charge_filter_id END AS charge_filter_id,
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN charge_filter_updated_at END AS charge_filter_updated_at,
    CASE WHEN COALESCE(match_score, -1) >= 0 THEN filters END AS filters,
    pay_in_advance,
    -- NOTE: custom expression evaluation (billable_metrics.expression) is not
    -- applied yet — phase 2 ships it as a WASM UDF built from lago-expression.
    CASE WHEN aggregation_type_code = 0 THEN '1'
         ELSE properties ->> field_name
    END AS value,
    extract_grouped_by(pricing_group_keys, properties, COALESCE(accepts_target_wallet, false)) AS grouped_by,
    CASE WHEN COALESCE(accepts_target_wallet, false) THEN properties ->> 'target_wallet_code' END AS target_wallet_code
FROM latest_delivery;
