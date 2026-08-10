#!/usr/bin/env bash
# Wallet refresh latency probe: event produced -> wallets.ongoing_usage_balance_cents
# updated, measured against the RWB bench wallet (rwb_sub_0), whose balance only
# moves on probe events. Run it WHILE the load producer hammers the rwbl_* subs to
# measure the trigger path under load. Same value-change methodology as
# full_path_benchmark.sh's wallet stage (poll interval 50ms), so numbers are
# comparable with the idle benchmark.
# Usage: wallet_latency_probe.sh <n_probes> <spacing_s> <outfile.jsonl>
set -uo pipefail
N=$1; SPACING=$2; OUT=$3
ORG="791d70ac-ec99-41ca-b3ce-af19ee5171fa"
SUB_EXT="rwb_sub_0"
CODE="rwb_sum_filtered"
WALLET_NAME="RWB Wallet"

pg() { docker exec lago_db_dev psql -U lago -d lago -tA -c "$1"; }
wallet_val() { pg "select ongoing_usage_balance_cents from wallets where name='$WALLET_NAME';"; }

for i in $(seq 1 "$N"); do
  BASE=$(wallet_val)
  TX="rwb-walletlat-$$-$i"
  TS=$(date +%s); NOW=$(date -u +%Y-%m-%dT%H:%M:%S.%3N); T0=$(date +%s%3N)
  echo '{"organization_id":"'$ORG'","external_subscription_id":"'$SUB_EXT'","transaction_id":"'$TX'","timestamp":"'$TS'.000","code":"'$CODE'","precise_total_amount_cents":"0.0","properties":{"tier":"gold","amount":"10"},"ingested_at":"'$NOW'","source":"http_ruby","source_metadata":{"api_post_processed":false}}' \
    | docker exec -i lago_redpanda_dev rpk topic produce events-raw >/dev/null
  MS=null
  DEADLINE=$(( $(date +%s%3N) + 30000 ))
  while [ "$(date +%s%3N)" -lt "$DEADLINE" ]; do
    [ "$(wallet_val)" != "$BASE" ] && MS=$(( $(date +%s%3N) - T0 )) && break
    sleep 0.05
  done
  echo "{\"probe\":$i,\"tx\":\"$TX\",\"wallet_ms\":$MS}" | tee -a "$OUT"
  sleep "$SPACING"
done
