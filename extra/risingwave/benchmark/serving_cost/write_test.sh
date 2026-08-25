#!/bin/bash
# Write-side test: same row rate, different commit cadence.
#   $1 = table suffix, $2 = inserts per second, $3 = rows per insert, $4 = seconds
set -e
CH="docker exec lago_clickhouse_dev clickhouse-client --user default --password default"
T=$1; IPS=$2; RPI=$3; SECS=$4
$CH -q "DROP TABLE IF EXISTS bench.w_$T"
$CH -q "CREATE TABLE bench.w_$T AS bench.buckets"
SLEEP=$(python3 -c "print(1.0/$IPS)")
END=$(( $(date +%s) + SECS ))
i=0
while [ $(date +%s) -lt $END ]; do
  $CH -q "
    INSERT INTO bench.w_$T (bucket, organization_id, subscription_id, customer_id, plan_id, code,
      target_wallet_code, charge_id, charge_filter_id, grouped_by, aggregation_type,
      events_count, units, last_event_at, last_ingested_at, is_deleted)
    SELECT toDateTime64('2026-08-01 00:00:00',3) + INTERVAL (number % 96 * 15) MINUTE,
      'org-bench', concat('sub-', leftPad(toString(number % $RPI), 6, '0')), 'cus-1', 'plan-1',
      'bm-0', NULL, 'chg-0', '', '{}', 'sum_agg',
      toInt64($i), toDecimal128($i, 26),
      now64(3), now64(3), 0
    FROM numbers($RPI)" &
  i=$((i+1))
  sleep $SLEEP
done
wait
echo "$T: $i inserts issued"
