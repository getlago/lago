-- matching_filter v3: dimension stats and a decision check against the
-- production matching_filter (batch queries only, nothing is created).
--
--   psql -h localhost -p 4566 -d dev -U root -f extra/risingwave/matching_filter_v3/stats.sql
--
-- decision_mismatches must be 0.

\timing on

-- 1. How charges are routed, and how big the lookup is.
SELECT
    count(*) AS charges,
    count(*) FILTER (WHERE fallback) AS fallback_charges,
    count(*) FILTER (WHERE NOT fallback AND shape_count = 0) AS charges_without_shapes,
    max(shape_count) FILTER (WHERE NOT fallback) AS max_lookup_shapes,
    max(shape_count) AS max_shapes
FROM filter_lookup_charges;

SELECT shape_count, fallback, count(*) AS charges
FROM filter_lookup_charges
GROUP BY shape_count, fallback
ORDER BY shape_count, fallback;

SELECT
    count(*) AS lookup_rows,
    count(DISTINCT charge_id) AS charges_with_rows,
    max(length(lookup_key)) AS max_key_bytes
FROM filter_lookup;

-- The fallback charges, biggest first: these still pay the production cost.
SELECT flc.organization_id, flc.charge_id, flc.shape_count, jsonb_array_length(ffa.filters_agg) AS filters
FROM filter_lookup_charges flc
JOIN flat_filters_agg ffa
    ON ffa.organization_id = flc.organization_id
   AND ffa.plan_id = flc.plan_id
   AND ffa.billable_metric_code = flc.billable_metric_code
   AND ffa.charge_id = flc.charge_id
WHERE flc.fallback
ORDER BY filters DESC
LIMIT 20;

-- 2. Decision parity on real events, without the shadow: v3 (event keys ->
--    lookup -> best rank) vs matching_filter, over the latest 100k
--    events_enriched rows against the CURRENT catalog, lookup charges only.
WITH sample AS (
    SELECT transaction_id, organization_id, external_subscription_id, code, properties, event_ts
    FROM events_enriched
    ORDER BY kafka_timestamp DESC
    LIMIT 100000
),
pairs AS (
    SELECT
        s.transaction_id,
        s.properties,
        flc.charge_id,
        flc.shapes,
        ffa.filters_agg
    FROM sample s
    JOIN subscriptions_agg sa
        ON sa.organization_id = s.organization_id
       AND sa.external_id = s.external_subscription_id
    JOIN filter_lookup_charges flc
        ON flc.organization_id = s.organization_id
       AND flc.plan_id = pick_subscription(sa.subs, s.event_ts) ->> 'plan_id'
       AND flc.billable_metric_code = s.code
    JOIN flat_filters_agg ffa
        ON ffa.organization_id = flc.organization_id
       AND ffa.plan_id = flc.plan_id
       AND ffa.billable_metric_code = flc.billable_metric_code
       AND ffa.charge_id = flc.charge_id
    WHERE NOT flc.fallback
),
keys AS (
    SELECT transaction_id, charge_id, k.lookup_key
    FROM pairs,
         unnest(filter_lookup_event_keys(shapes, COALESCE(properties, '{}'::jsonb))) AS k(lookup_key)
),
best AS (
    SELECT k.transaction_id, k.charge_id, max(fl.rank) AS best_rank
    FROM keys k
    JOIN filter_lookup fl
        ON fl.charge_id = k.charge_id
       AND fl.lookup_key = k.lookup_key
    GROUP BY k.transaction_id, k.charge_id
),
compared AS (
    SELECT
        matching_filter(p.filters_agg, COALESCE(p.properties, '{}'::jsonb)) ->> 'charge_filter_id' AS expected,
        p.filters_agg -> (999999999 - b.best_rank % 1000000000)::INT ->> 'charge_filter_id' AS actual
    FROM pairs p
    LEFT JOIN best b
        ON b.transaction_id = p.transaction_id
       AND b.charge_id = p.charge_id
)
SELECT
    count(*) AS event_charge_pairs,
    count(*) FILTER (WHERE actual IS NOT NULL) AS matched_a_filter,
    count(*) FILTER (WHERE expected IS DISTINCT FROM actual) AS decision_mismatches
FROM compared;
