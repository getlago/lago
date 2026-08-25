#!/bin/bash
# Same bucket volume, but spread over many orgs with UUID-shaped ids, so
# subscription_id-only filters must probe every org range (prod shape).
set -e
CH="docker exec lago_clickhouse_dev clickhouse-client --user default --password default"
ORGS=${1:-500}; SUBS_PER_ORG=${2:-40}; STEP=${3:-25}
for (( o=0; o<ORGS; o+=STEP )); do
  $CH --max_memory_usage 8000000000 -q "
  INSERT INTO bench.buckets_mo
    (bucket, organization_id, subscription_id, customer_id, plan_id, code, target_wallet_code,
     charge_id, charge_filter_id, grouped_by, aggregation_type, events_count, units,
     last_event_at, last_ingested_at, is_deleted)
  SELECT
    toDateTime64('2026-08-01 00:00:00', 3) + INTERVAL (b * 15) MINUTE AS bucket,
    lower(hex(MD5(toString(org)))) AS organization_id,
    lower(hex(MD5(concat('sub', toString(org), '-', toString(sub))))) AS subscription_id,
    lower(hex(MD5(concat('cus', toString(sub))))) AS customer_id,
    'plan-bench' AS plan_id, concat('bm-', toString(c)) AS code, NULL AS target_wallet_code,
    lower(hex(MD5(concat('chg', toString(c))))) AS charge_id,
    '' AS charge_filter_id, '{}' AS grouped_by, 'sum_agg' AS aggregation_type,
    toInt64(5 + (cityHash64(sub, c, b) % 40)) AS events_count,
    toDecimal128(1 + (cityHash64(sub, c, b) % 1000), 26) AS units,
    bucket + INTERVAL 600 SECOND AS last_event_at,
    bucket + INTERVAL 601 SECOND AS last_ingested_at,
    0 AS is_deleted
  FROM (
    SELECT number AS n,
           $o + intDiv(n, $SUBS_PER_ORG * 3 * 2880) AS org,
           intDiv(n % ($SUBS_PER_ORG * 3 * 2880), 3 * 2880) AS sub,
           intDiv(n % (3 * 2880), 2880) AS c,
           n % 2880 AS b
    FROM numbers($STEP * $SUBS_PER_ORG * 3 * 2880)
  )
  SETTINGS max_insert_threads = 4"
  echo "orgs $o..$((o+STEP)) done"
done
