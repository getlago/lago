-- matching_filter_v2 evaluation: v1 vs v2 parity checks (batch queries only,
-- nothing is created). Run with:
--
--   psql -h localhost -p 4566 -d dev -U root -f extra/risingwave/sql/matching_filter_v2/04_parity_check.sql
--
-- Every *_mismatches column must be 0.

\timing on

-- 1. Dimension parity: flat_filters_agg_v2 must hold the same arrays, in the
--    same order, as flat_filters_agg (v2 returns POSITIONS into them), and
--    has_filters must agree with the candidates' filters.
SELECT
    count(*) AS charges,
    count(*) FILTER (WHERE v2.charge_id IS NULL) AS missing_in_v2,
    count(*) FILTER (WHERE (v1.filters_agg IS DISTINCT FROM v2.filters_agg)) AS filters_agg_mismatches,
    count(*) FILTER (WHERE v2.filters_text::jsonb IS DISTINCT FROM v2.filters_agg) AS filters_text_mismatches,
    count(*) FILTER (
        WHERE v2.has_filters IS DISTINCT FROM (v1.filters_agg -> 0 -> 'filters' IS NOT NULL
                                               AND jsonb_typeof(v1.filters_agg -> 0 -> 'filters') <> 'null')
    ) AS has_filters_mismatches,
    max(jsonb_array_length(v1.filters_agg)) AS max_filters_per_charge,
    max(length(v2.filters_text)) AS max_filters_text_bytes
FROM flat_filters_agg v1
LEFT JOIN flat_filters_agg_v2 v2
    ON v2.organization_id = v1.organization_id
   AND v2.plan_id = v1.plan_id
   AND v2.billable_metric_code = v1.billable_metric_code
   AND v2.charge_id = v1.charge_id;

-- 2. Decision parity on real events, without the shadow pipeline: both UDFs
--    over the latest 100k events_enriched rows against the CURRENT catalog.
--    Batch joins, not temporal ones, so both sides see the same dimensions.
WITH sample AS (
    SELECT organization_id, external_subscription_id, code, properties, event_ts
    FROM events_enriched
    ORDER BY kafka_timestamp DESC
    LIMIT 100000
),
subscribed AS (
    SELECT s.*, pick_subscription(sa.subs, s.event_ts) ->> 'plan_id' AS plan_id
    FROM sample s
    JOIN subscriptions_agg sa
        ON sa.organization_id = s.organization_id
       AND sa.external_id = s.external_subscription_id
),
compared AS (
    SELECT
        v2.filters_agg,
        matching_filter(v1.filters_agg, COALESCE(s.properties, '{}'::jsonb)) AS mf,
        CASE WHEN NOT v2.has_filters THEN -1
             ELSE matching_filter_v2(v2.filters_text, COALESCE(s.properties, '{}'::jsonb))
        END AS idx
    FROM subscribed s
    JOIN flat_filters_agg v1
        ON v1.organization_id = s.organization_id
       AND v1.plan_id = s.plan_id
       AND v1.billable_metric_code = s.code
    JOIN flat_filters_agg_v2 v2
        ON v2.organization_id = v1.organization_id
       AND v2.plan_id = v1.plan_id
       AND v2.billable_metric_code = v1.billable_metric_code
       AND v2.charge_id = v1.charge_id
)
SELECT
    count(*) AS event_charge_pairs,
    count(*) FILTER (WHERE idx >= 0) AS matched_a_filter,
    count(*) FILTER (
        WHERE (mf ->> 'charge_filter_id') IS DISTINCT FROM
              (CASE WHEN idx >= 0 THEN filters_agg -> idx ->> 'charge_filter_id' END)
    ) AS filter_mismatches,
    count(*) FILTER (
        WHERE (mf -> 'pricing_group_keys') IS DISTINCT FROM
              (CASE WHEN idx >= 0 THEN filters_agg -> idx -> 'pricing_group_keys'
                    ELSE NULLIF(filters_agg -> 0 -> 'pricing_group_keys', 'null'::jsonb)
               END)
    ) AS pricing_group_keys_mismatches
FROM compared;

-- 3. Shadow parity (only once 03_events_expanded_v2.sql is applied): rows of
--    events that arrived AFTER the shadow was created, so both stages matched
--    them live against the same catalog. Backfilled rows are left out on
--    purpose: v1 matched them against the catalog of their time, v2 against
--    today's, so filter edits since then would show up as false mismatches.
--    rw_expanded_at is not compared (it is the insert time of each table).
WITH since AS (
    SELECT min(rw_expanded_at) + INTERVAL '1 minute' AS t FROM events_expanded_v2
),
v1 AS (
    SELECT * FROM events_expanded WHERE kafka_timestamp > (SELECT t FROM since)
),
v2 AS (
    SELECT * FROM events_expanded_v2 WHERE kafka_timestamp > (SELECT t FROM since)
)
SELECT
    count(*) AS rows_compared,
    count(*) FILTER (WHERE v1.transaction_id IS NULL) AS only_in_v2,
    count(*) FILTER (WHERE v2.transaction_id IS NULL) AS only_in_v1,
    count(*) FILTER (
        WHERE v1.transaction_id IS NOT NULL AND v2.transaction_id IS NOT NULL
          AND ((v1.charge_filter_id IS DISTINCT FROM v2.charge_filter_id)
            OR (v1.charge_filter_updated_at IS DISTINCT FROM v2.charge_filter_updated_at)
            OR (v1.filters IS DISTINCT FROM v2.filters)
            OR (v1.grouped_by IS DISTINCT FROM v2.grouped_by)
            OR (v1.target_wallet_code IS DISTINCT FROM v2.target_wallet_code)
            OR (v1."value" IS DISTINCT FROM v2."value")
            OR (v1.pay_in_advance IS DISTINCT FROM v2.pay_in_advance)
            OR (v1.subscription_id IS DISTINCT FROM v2.subscription_id))
    ) AS column_mismatches
FROM v1
FULL OUTER JOIN v2
    ON v2.organization_id = v1.organization_id
   AND v2.code = v1.code
   AND v2.external_subscription_id = v1.external_subscription_id
   AND v2.event_ts = v1.event_ts
   AND v2.transaction_id = v1.transaction_id
   AND v2.charge_id IS NOT DISTINCT FROM v1.charge_id;
