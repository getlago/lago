#!/bin/bash
# Generate events_enriched-shaped rows for the same subscriptions.
#  tier "medium": EVENTS_PER_SUB events spread over 30 days
set -e
CH="docker exec lago_clickhouse_dev clickhouse-client --user default --password default"
START=$1; END=$2; PER_SUB=$3; STEP=${4:-10}
for (( s=START; s<END; s+=STEP )); do
  $CH --max_memory_usage 8000000000 -q "
  INSERT INTO bench.events
    (organization_id, external_subscription_id, code, timestamp, transaction_id,
     properties, value, precise_total_amount_cents)
  SELECT
    'org-bench' AS organization_id,
    concat('sub-', leftPad(toString($s + intDiv(number, $PER_SUB)), 6, '0')) AS external_subscription_id,
    'bm-0' AS code,
    toDateTime64('2026-08-01 00:00:00', 3) + toIntervalMillisecond(toInt64((number % $PER_SUB) * (2592000000 / $PER_SUB))) AS timestamp,
    lower(hex(MD5(toString(number) || toString($s)))) AS transaction_id,
    map('region', ['eu','us','ap'][1 + (number % 3)],
        'tier',   ['free','pro','ent'][1 + (number % 3)],
        'value',  toString(1 + (cityHash64(number) % 500))) AS properties,
    toString(1 + (cityHash64(number) % 500)) AS value,
    NULL AS precise_total_amount_cents
  FROM numbers($STEP * $PER_SUB)
  SETTINGS max_insert_threads = 4
  "
  echo "events: subs $s done"
done
