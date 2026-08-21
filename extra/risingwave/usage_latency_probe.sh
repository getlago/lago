#!/usr/bin/env bash
# Measure ingest -> QUERYABLE-in-usage_buckets_15m latency (what a pgwire reader
# like Rails actually experiences, including checkpoint visibility).
#
# Produces one event at a time to events-raw and polls usage_buckets_15m until
# events_count increments. Poll resolution is one psql round-trip (~15-30ms).
#
# Usage: ./extra/risingwave/usage_latency_probe.sh [iterations]
set -euo pipefail

ITERATIONS="${1:-10}"
RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"

# Test fixture from the dev seeds (see README): sum metric with dim filters.
ORG="791d70ac-ec99-41ca-b3ce-af19ee5171fa"
SUB_EXT="bench_sub_8bf23869"
CODE="bench_bm_20_8bf23869"

q() { psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -tA -c "$1"; }

count_query="SELECT COALESCE(SUM(events_count), 0) FROM usage_buckets_15m
             WHERE organization_id = '$ORG' AND code = '$CODE';"

total=0
for i in $(seq 1 "$ITERATIONS"); do
  before=$(q "$count_query")
  ts="$(date +%s).000"
  now="$(date -u +%Y-%m-%dT%H:%M:%S.%3N)"
  tx="rw-usage-probe-$$-$i"
  printf '{"organization_id":"%s","external_subscription_id":"%s","transaction_id":"%s","timestamp":"%s","code":"%s","precise_total_amount_cents":"0.0","properties":{"dim":"v16","value":"1"},"ingested_at":"%s","source":"http_ruby","source_metadata":{"api_post_processed":true}}\n' \
    "$ORG" "$SUB_EXT" "$tx" "$ts" "$CODE" "$now" \
    | docker exec -i lago_redpanda_dev rpk topic produce events-raw >/dev/null

  t0=$(date +%s%3N)
  while true; do
    after=$(q "$count_query")
    if [ "$after" -gt "$before" ]; then break; fi
    if [ $(( $(date +%s%3N) - t0 )) -gt 15000 ]; then
      echo "iter $i: TIMEOUT (>15s)"; exit 1
    fi
  done
  ms=$(( $(date +%s%3N) - t0 ))
  total=$((total + ms))
  echo "iter $i: visible in usage_buckets_15m after ${ms}ms"
done

echo "avg over $ITERATIONS: $((total / ITERATIONS))ms (poll resolution ~1 psql round-trip)"
