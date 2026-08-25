#!/bin/bash
CH() { docker exec lago_clickhouse_dev clickhouse-client --user default --password default "$@"; }
ORG=$(CH -q "SELECT lower(hex(MD5('250')))")
SUB=$(CH -q "SELECT lower(hex(MD5('sub250-20')))")
CHG=$(CH -q "SELECT lower(hex(MD5('chg0')))")
echo "ids: $ORG / $SUB / $CHG"
CH -q "DROP TABLE IF EXISTS bench.frag"
CH -q "CREATE TABLE bench.frag AS bench.buckets"
CH -q "SYSTEM STOP MERGES bench.frag"
# base: 40 orgs' worth of buckets so index analysis is realistic
CH -q "INSERT INTO bench.frag SELECT * EXCEPT(ver) FROM bench.buckets_mo WHERE organization_id IN (SELECT DISTINCT organization_id FROM bench.buckets_mo LIMIT 40)"
Q="SELECT count(), sum(events_count), sum(units) FROM bench.frag FINAL WHERE organization_id='$ORG' AND subscription_id='$SUB' AND charge_id='$CHG' AND charge_filter_id='' AND grouped_by='{}' AND bucket >= toDateTime64('2026-08-01 00:00:00',3) AND bucket <= toDateTime64('2026-08-31 00:00:00',3)"
ADD="INSERT INTO bench.frag SELECT * EXCEPT(ver) FROM bench.buckets_mo WHERE organization_id='$ORG' AND subscription_id='$SUB'"
measure() { P=$(CH -q "SELECT count() FROM system.parts WHERE database='bench' AND table='frag' AND active"); echo "measuring at $P parts"; for i in 1 2 3; do CH --query_id "fr2_${P}_${i}" -q "$Q" >/dev/null; done; }
measure
for round in 1 2 3 4; do
  for k in $(seq 1 9); do CH -q "$ADD"; done
  measure
done
CH -q "SYSTEM START MERGES bench.frag"
CH -q "SYSTEM FLUSH LOGS" >/dev/null
CH -q "
SELECT toUInt32(replaceRegexpOne(query_id,'^fr2_([0-9]+)_[0-9]+\$','\1')) AS active_parts,
  round(median(query_duration_ms),1) ms,
  formatReadableQuantity(median(read_rows)) rows_read,
  round(median(ProfileEvents['OSCPUVirtualTimeMicroseconds'])/1000,1) cpu_ms
FROM system.query_log WHERE type='QueryFinish' AND query_id LIKE 'fr2\_%' AND event_time > now() - INTERVAL 30 MINUTE
GROUP BY active_parts ORDER BY active_parts FORMAT PrettyCompact"
