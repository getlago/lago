#!/bin/bash
set -e
CH() { docker exec lago_clickhouse_dev clickhouse-client --user default --password default "$@"; }
COLS="bucket, organization_id, subscription_id, customer_id, plan_id, code, target_wallet_code, charge_id, charge_filter_id, grouped_by, aggregation_type, events_count, units, last_event_at, last_ingested_at, is_deleted"
SRC="SELECT DISTINCT organization_id FROM bench.buckets_mo LIMIT 40"
for t in flat part; do
  CH -q "DROP TABLE IF EXISTS bench.p_$t"
done
CH -q "CREATE TABLE bench.p_flat AS bench.buckets"
CH -q "CREATE TABLE bench.p_part (
    bucket DateTime64(3), organization_id String, subscription_id String, customer_id String,
    plan_id Nullable(String), code String, target_wallet_code Nullable(String),
    charge_id String, charge_filter_id String, grouped_by String, aggregation_type String,
    events_count Int64, units Decimal(38, 26), last_event_at DateTime64(3),
    last_ingested_at DateTime64(3), is_deleted UInt8 DEFAULT 0,
    ver DateTime64(3) MATERIALIZED now64(3))
  ENGINE = ReplacingMergeTree(ver, is_deleted)
  PARTITION BY toYYYYMM(bucket)
  ORDER BY (organization_id, subscription_id, charge_id, charge_filter_id, grouped_by, bucket)"
# 6 months of history: Aug 2026 shifted back 0..5 months
for t in flat part; do
  for m in 0 1 2 3 4 5; do
    CH --max_memory_usage 8000000000 -q "
      INSERT INTO bench.p_$t ($COLS)
      SELECT bucket - INTERVAL $m MONTH, organization_id, subscription_id, customer_id, plan_id, code,
             target_wallet_code, charge_id, charge_filter_id, grouped_by, aggregation_type,
             events_count, units, last_event_at, last_ingested_at, is_deleted
      FROM bench.buckets_mo WHERE organization_id IN ($SRC)"
  done
  echo "$t loaded: $(CH -q "SELECT count() FROM bench.p_$t")"
done
# the parity sweep: recent-activity window across all orgs
for t in flat part; do
  for i in 1 2 3; do
    CH --query_id "sweep_${t}_${i}" --max_memory_usage 10000000000 -q "
      SELECT DISTINCT subscription_id FROM bench.p_$t FINAL
      WHERE bucket >= toDateTime64('2026-07-25 00:00:00',3) LIMIT 100" > /dev/null
  done
done
CH -q "SYSTEM FLUSH LOGS" >/dev/null
CH -q "
SELECT replaceRegexpOne(query_id,'^sweep_([a-z]+)_[0-9]+\$','\1') AS table,
  round(median(query_duration_ms),1) ms,
  formatReadableQuantity(median(read_rows)) rows_read,
  round(median(ProfileEvents['OSCPUVirtualTimeMicroseconds'])/1000,1) cpu_ms
FROM system.query_log WHERE type='QueryFinish' AND query_id LIKE 'sweep\_%' AND event_time > now() - INTERVAL 30 MINUTE
GROUP BY table ORDER BY cpu_ms DESC FORMAT PrettyCompact"
