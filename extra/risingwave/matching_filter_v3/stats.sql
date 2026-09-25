-- matching_filter v3: dimension stats and decision checks (batch queries
-- only, nothing is created).
--
--   psql -h localhost -p 4566 -d dev -U root -f extra/risingwave/matching_filter_v3/stats.sql
--
-- lookup_vs_scan_mismatches must be 0. changed_vs_production counts the
-- events whose filter differs from production RisingWave because v3 follows
-- the API's rules (see sql/03_enrichment_v3.sql).

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

-- 2. Decisions on real events, without the shadow, over the latest 100k
--    events_enriched rows against the CURRENT catalog, lookup charges only:
--    the lookup path (event keys -> filter_lookup -> best rank) must agree
--    with filter_lookup_fallback, a full scan of filters_agg with the same
--    rules; and the result is compared with production matching_filter.
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
        flc.empty_filter_rank,
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
hits AS (
    SELECT k.transaction_id, k.charge_id, max(fl.rank) AS hit_rank
    FROM keys k
    JOIN filter_lookup fl
        ON fl.charge_id = k.charge_id
       AND fl.lookup_key = k.lookup_key
    GROUP BY k.transaction_id, k.charge_id
),
compared AS (
    SELECT
        CASE WHEN GREATEST(h.hit_rank, p.empty_filter_rank) IS NULL THEN -1
             ELSE (GREATEST(h.hit_rank, p.empty_filter_rank) % 1000000)::INT
        END AS lookup_pos,
        filter_lookup_fallback(p.filters_agg, COALESCE(p.properties, '{}'::jsonb)) AS scan_pos,
        matching_filter(p.filters_agg, COALESCE(p.properties, '{}'::jsonb)) ->> 'charge_filter_id' AS production_filter,
        p.filters_agg
    FROM pairs p
    LEFT JOIN hits h
        ON h.transaction_id = p.transaction_id
       AND h.charge_id = p.charge_id
)
SELECT
    count(*) AS event_charge_pairs,
    count(*) FILTER (WHERE lookup_pos >= 0) AS matched_a_filter,
    count(*) FILTER (WHERE lookup_pos IS DISTINCT FROM scan_pos) AS lookup_vs_scan_mismatches,
    count(*) FILTER (
        WHERE (CASE WHEN lookup_pos >= 0 THEN filters_agg -> lookup_pos ->> 'charge_filter_id' END)
              IS DISTINCT FROM production_filter
    ) AS changed_vs_production
FROM compared;
