#!/usr/bin/env bash
# Samples pipeline health every INTERVAL seconds during a load test; one JSON
# line per sample. Usage: sampler.sh <duration_s> <outfile> [interval_s]
set -uo pipefail
DUR=$1; OUT=$2; INTERVAL=${3:-5}
END=$(( $(date +%s) + DUR ))

hwm() { docker exec lago_redpanda_dev rpk topic describe -p "$1" 2>/dev/null | awk 'NR>1 {s+=$6} END {print s+0}'; }
lag() { docker exec lago_redpanda_dev rpk group describe -s "$1" 2>/dev/null | awk '$1=="TOTAL-LAG" {print $2; f=1} END {if(!f) print 0}'; }

while [ "$(date +%s)" -lt "$END" ]; do
  TS=$(date +%s%3N)
  RAW=$(hwm events-raw)
  SHADOW=$(hwm events_enriched_expanded_shadow)
  TRIGGERS=$(hwm wallet_refresh_triggers)
  WLAG=$(lag lago_wallet_refresh_triggers_consumer)

  PGSTATS=$(docker exec lago_db_dev psql -U lago -d lago -tA -c \
    "select count(*) || ' ' || coalesce(extract(epoch from (now() - max(last_ingested_at)))::int, -1) from usage_realtime_projections;" 2>/dev/null)
  PROJ_ROWS=${PGSTATS%% *}; PROJ_STALE=${PGSTATS##* }
  WSYNCED=$(docker exec lago_db_dev psql -U lago -d lago -tA -c \
    "select count(*) from wallets where last_ongoing_balance_sync_at > now() - interval '${INTERVAL} seconds';" 2>/dev/null)

  RW=$(psql -h localhost -p 4566 -d dev -U root -tA -c \
    "select coalesce((select e2e_avg_ms || ' ' || e2e_max_ms || ' ' || events from pipeline_latency_e2e order by window_start desc limit 1), '0 0 0');" 2>/dev/null)
  E2E_AVG=$(echo "$RW" | awk '{print $1}'); E2E_MAX=$(echo "$RW" | awk '{print $2}'); E2E_N=$(echo "$RW" | awk '{print $3}')
  UL=$(psql -h localhost -p 4566 -d dev -U root -tA -c \
    "select coalesce((select usage_avg_ms || ' ' || usage_max_ms from usage_latency order by window_start desc limit 1), '0 0');" 2>/dev/null)
  U_AVG=$(echo "$UL" | awk '{print $1}'); U_MAX=$(echo "$UL" | awk '{print $2}')

  STATS=$(docker stats --no-stream --format '{{.Name}} {{.CPUPerc}}' lago_risingwave_dev lago_db_dev lago_redpanda_dev lago_events-processor lago_api_events_consumer_dev lago_clickhouse_dev 2>/dev/null | tr -d '%' | awk '{printf "\"%s\":%s,", $1, $2}')

  echo "{\"ts\":$TS,\"raw_hwm\":$RAW,\"shadow_hwm\":$SHADOW,\"trigger_hwm\":$TRIGGERS,\"wallet_lag\":${WLAG:-0},\"proj_rows\":${PROJ_ROWS:-0},\"proj_stale_s\":${PROJ_STALE:--1},\"wallets_synced\":${WSYNCED:-0},\"e2e_avg_ms\":${E2E_AVG:-0},\"e2e_max_ms\":${E2E_MAX:-0},\"e2e_events\":${E2E_N:-0},\"usage_avg_ms\":${U_AVG:-0},\"usage_max_ms\":${U_MAX:-0},\"cpu\":{${STATS%,}}}" >> "$OUT"
  sleep "$INTERVAL"
done
