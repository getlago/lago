#!/usr/bin/env bash
# Full-path latency benchmark: per-step timings for the legacy path
# (Go events-processor -> ClickHouse -> flag/clock wallet refresh) vs the
# RisingWave path (enrichment -> projections -> trigger consumer).
#
# Steps measured per event (all from broker timestamps / store polling, no
# Rails boot noise):
#   ingestion : event produced -> visible on events-raw (broker ts)
#   enriched  : -> enriched event on events_enriched_expanded (old, Go) or
#                  events_enriched_expanded_shadow (new, RisingWave)
#   usage     : -> usage readable by the serving store (ClickHouse row
#                  queryable vs usage_realtime_projections row updated)
#   wallet    : -> wallets.ongoing_usage_balance_cents updated
#
# Phase "new": trigger consumer running. Phase "old": consumer stopped so the
# wallet updates only through the legacy flag -> clock -> job chain (up to
# 10s flag consume + up to 300s refresh interval in dev defaults).
#
# Usage: ./full_path_benchmark.sh new|old <n_events> <spacing_seconds> <outfile>
set -uo pipefail

PHASE=$1; N=$2; SPACING=$3; OUT=$4
ORG="791d70ac-ec99-41ca-b3ce-af19ee5171fa"
SUB_EXT="rwb_sub_0"
CODE="rwb_sum_filtered"
WALLET_NAME="RWB Wallet"
WORK=$(mktemp -d)

if [ "$PHASE" = "new" ]; then ENRICHED_TOPIC=events_enriched_expanded_shadow; else ENRICHED_TOPIC=events_enriched_expanded; fi
WALLET_TIMEOUT=$([ "$PHASE" = "new" ] && echo 60000 || echo 420000)

pg() { docker exec lago_db_dev psql -U lago -d lago -tA -c "$1"; }
ch() { docker exec lago_clickhouse_dev clickhouse-client --password default -q "$1"; }

wallet_val() { pg "select ongoing_usage_balance_cents from wallets where name='$WALLET_NAME';"; }

usage_visible() { # $1=tx  -> 0 exit when the serving store has the event
  if [ "$PHASE" = "new" ]; then
    [ "$(pg "select units from usage_realtime_projections where subscription_id=(select id from subscriptions where external_id='$SUB_EXT') and charge_filter_id <> '' and grouped_by='{}';")" != "$BASE_UNITS" ]
  else
    [ "$(ch "select count() from default.events_enriched_expanded where transaction_id='$1'")" != "0" ]
  fi
}

for i in $(seq 1 "$N"); do
  TX="rwb-full-$PHASE-$$-$i"
  RAW_F="$WORK/raw_$i"; ENR_F="$WORK/enr_$i"

  # arm topic watchers before producing
  (timeout 120 docker exec lago_redpanda_dev rpk topic consume events-raw --offset end -f '%d %v\n' 2>/dev/null | grep -m1 "$TX" > "$RAW_F") &
  (timeout 420 docker exec lago_redpanda_dev rpk topic consume "$ENRICHED_TOPIC" --offset end -f '%d %v\n' 2>/dev/null | grep -m1 "$TX" > "$ENR_F") &
  sleep 2

  BASE_UNITS=$(pg "select units from usage_realtime_projections where subscription_id=(select id from subscriptions where external_id='$SUB_EXT') and charge_filter_id <> '' and grouped_by='{}';")
  BASE_WALLET=$(wallet_val)

  TS=$(date +%s); NOW=$(date -u +%Y-%m-%dT%H:%M:%S.%3N); T0=$(date +%s%3N)
  echo '{"organization_id":"'$ORG'","external_subscription_id":"'$SUB_EXT'","transaction_id":"'$TX'","timestamp":"'$TS'.000","code":"'$CODE'","precise_total_amount_cents":"0.0","properties":{"tier":"gold","amount":"10"},"ingested_at":"'$NOW'","source":"http_ruby","source_metadata":{"api_post_processed":false}}' \
    | docker exec -i lago_redpanda_dev rpk topic produce events-raw >/dev/null
  # api_post_processed=false so the Go processor runs its full post-processing
  # (incl. the Redis refresh flag the legacy wallet chain depends on).

  # ingestion + enriched from broker timestamps
  INGEST_MS=""; ENRICH_MS=""
  for _ in $(seq 1 1200); do
    [ -z "$INGEST_MS" ] && [ -s "$RAW_F" ] && INGEST_MS=$(( $(awk '{print $1}' "$RAW_F") - T0 ))
    [ -z "$ENRICH_MS" ] && [ -s "$ENR_F" ] && ENRICH_MS=$(( $(awk '{print $1}' "$ENR_F") - T0 ))
    [ -n "$INGEST_MS" ] && [ -n "$ENRICH_MS" ] && break
    sleep 0.05
  done

  # usage visibility in the serving store
  USAGE_MS=""
  while true; do
    if usage_visible "$TX"; then USAGE_MS=$(( $(date +%s%3N) - T0 )); break; fi
    [ $(( $(date +%s%3N) - T0 )) -gt 120000 ] && break
    sleep 0.05
  done

  # wallet refreshed
  WALLET_MS=""
  while true; do
    [ "$(wallet_val)" != "$BASE_WALLET" ] && WALLET_MS=$(( $(date +%s%3N) - T0 )) && break
    [ $(( $(date +%s%3N) - T0 )) -gt "$WALLET_TIMEOUT" ] && break
    sleep 0.2
  done

  echo "{\"phase\":\"$PHASE\",\"tx\":\"$TX\",\"ingestion_ms\":${INGEST_MS:-null},\"enriched_ms\":${ENRICH_MS:-null},\"usage_ms\":${USAGE_MS:-null},\"wallet_ms\":${WALLET_MS:-null}}" | tee -a "$OUT"

  [ "$i" -lt "$N" ] && sleep "$SPACING"
done
wait 2>/dev/null
rm -rf "$WORK"
