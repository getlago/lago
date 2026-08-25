#!/bin/bash
CH() { docker exec lago_clickhouse_dev clickhouse-client --user default --password default "$@"; }
ORG=$(CH -q "SELECT lower(hex(MD5('250')))")
SUB=$(CH -q "SELECT lower(hex(MD5('sub250-20')))")
CHG=$(CH -q "SELECT lower(hex(MD5('chg0')))")
echo "org=$ORG sub=$SUB chg=$CHG rows=$(CH -q "SELECT count() FROM bench.buckets_mo WHERE organization_id='$ORG' AND subscription_id='$SUB' AND charge_id='$CHG'")"

run() { # name, sql
  for i in 1 2 3 4 5; do
    CH --query_id "mo_${1}_${i}" --max_memory_usage 10000000000 -q "$2" > /dev/null 2>"${TMPDIR:-/tmp}/e_$1" || { echo "$1 FAILED: $(head -2 "${TMPDIR:-/tmp}/e_$1")"; return; }
  done
}

run point_with_org "SELECT count(), sum(events_count), sum(units) FROM bench.buckets_mo FINAL WHERE organization_id='$ORG' AND subscription_id='$SUB' AND charge_id='$CHG' AND charge_filter_id='' AND grouped_by='{}' AND bucket >= toDateTime64('2026-08-01 00:00:00',3) AND bucket <= toDateTime64('2026-08-31 00:00:00',3)"

run point_sub_only "SELECT count(), sum(events_count), sum(units) FROM bench.buckets_mo FINAL WHERE subscription_id='$SUB' AND bucket >= toDateTime64('2026-08-01 00:00:00',3) AND bucket <= toDateTime64('2026-08-31 00:00:00',3)"

run wallet_poll_sub_only "SELECT 1 FROM bench.buckets_mo WHERE subscription_id='$SUB' AND toUnixTimestamp64Milli(last_ingested_at) >= 1787000000000 LIMIT 1"

run wallet_poll_with_org "SELECT 1 FROM bench.buckets_mo WHERE organization_id='$ORG' AND subscription_id='$SUB' AND toUnixTimestamp64Milli(last_ingested_at) >= 1787000000000 LIMIT 1"

run parity_distinct "SELECT DISTINCT subscription_id FROM bench.buckets_mo FINAL WHERE bucket >= toDateTime64('2026-08-29 00:00:00',3) LIMIT 100"

CH -q "SYSTEM FLUSH LOGS" > /dev/null
CH -q "
SELECT replaceRegexpOne(query_id, '^mo_(.*)_[0-9]+\$', '\1') AS name,
  round(median(query_duration_ms),1) ms,
  formatReadableQuantity(median(read_rows)) rows_read,
  round(median(ProfileEvents['OSCPUVirtualTimeMicroseconds'])/1000,1) cpu_ms,
  formatReadableSize(median(memory_usage)) mem
FROM system.query_log WHERE type='QueryFinish' AND query_id LIKE 'mo\_%'
  AND event_time > now() - INTERVAL 20 MINUTE
GROUP BY name ORDER BY cpu_ms DESC FORMAT PrettyCompact"
