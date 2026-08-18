#!/bin/sh

set -eu

BASE_URL=$1
API_KEY=$2
RESPONSE_FILE=$(mktemp "${TMPDIR:-/tmp}/lago-agentic-ai-response.XXXXXX")
trap 'rm -f "$RESPONSE_FILE"' EXIT HUP INT TERM

call_api() {
  method=$1
  path=$2
  payload=${3:-}

  if [ -n "$payload" ]; then
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $API_KEY" \
      --data "$payload")
  else
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $API_KEY")
  fi

  case "$status" in
    2*) cat "$RESPONSE_FILE" ;;
    *) return 1 ;;
  esac
}

require_api() {
  method=$1
  path=$2
  payload=${3:-}
  if ! call_api "$method" "$path" "$payload"; then
    printf 'Lago API request failed: %s %s\n' "$method" "$path" >&2
    cat "$RESPONSE_FILE" >&2
    printf '\n' >&2
    exit 1
  fi
}

printf 'Waiting for the Lago API'
attempt=1
while [ "$attempt" -le 45 ]; do
  if call_api GET /billable_metrics >/dev/null 2>&1; then
    printf ' ready\n'
    break
  fi
  printf '.'
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 45 ] || {
  printf '\n' >&2
  printf 'Lago did not become ready within 45 seconds.\n' >&2
  exit 1
}

ensure_metric() {
  code=$1
  name=$2
  if metric=$(call_api GET "/billable_metrics/$code" 2>/dev/null); then
    printf '%s' "$metric"
    return
  fi
  payload=$(jq -n --arg code "$code" --arg name "$name" \
    '{billable_metric:{name:$name,code:$code,aggregation_type:"sum_agg",field_name:"tokens"}}')
  require_api POST /billable_metrics "$payload"
}

input_metric=$(ensure_metric agentic-ai-demo-input-tokens 'Input tokens')
input_metric_id=$(printf '%s' "$input_metric" | jq -er '.billable_metric.lago_id')
output_metric=$(ensure_metric agentic-ai-demo-output-tokens 'Output tokens')
output_metric_id=$(printf '%s' "$output_metric" | jq -er '.billable_metric.lago_id')

customer=$(jq -n '{customer:{external_id:"agentic-ai-demo-customer",name:"Agentic AI Demo Customer",currency:"USD"}}')
require_api POST /customers "$customer" >/dev/null

if ! call_api GET /plans/agentic-ai-demo-plan >/dev/null 2>&1; then
  plan=$(jq -n \
    --arg input "$input_metric_id" \
    --arg output "$output_metric_id" \
    '{plan:{name:"Agentic AI Demo",code:"agentic-ai-demo-plan",interval:"monthly",amount_cents:0,amount_currency:"USD",pay_in_advance:false,charges:[{billable_metric_id:$input,code:"input-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000002"}},{billable_metric_id:$output,code:"output-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000008"}}]}}')
  require_api POST /plans "$plan" >/dev/null
fi

subscription=$(jq -n '{subscription:{external_customer_id:"agentic-ai-demo-customer",plan_code:"agentic-ai-demo-plan",external_id:"agentic-ai-demo-subscription",billing_time:"anniversary"}}')
require_api POST /subscriptions "$subscription" >/dev/null

send_event() {
  transaction_id=$1
  code=$2
  tokens=$3
  event=$(jq -n \
    --arg transaction_id "$transaction_id" \
    --arg code "$code" \
    --argjson tokens "$tokens" \
    '{event:{transaction_id:$transaction_id,external_subscription_id:"agentic-ai-demo-subscription",code:$code,properties:{tokens:$tokens}}}')

  status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
    "$BASE_URL/events" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $API_KEY" \
    --data "$event")

  [ "$status" = "200" ] && return
  if [ "$status" = "422" ] && jq -e '.error_details.transaction_id[]? == "value_already_exist"' "$RESPONSE_FILE" >/dev/null; then
    return
  fi
  printf 'Event %s failed with HTTP %s.\n' "$transaction_id" "$status" >&2
  cat "$RESPONSE_FILE" >&2
  printf '\n' >&2
  exit 1
}

while read -r transaction_id code tokens; do
  send_event "$transaction_id" "$code" "$tokens"
done <<'EVENTS'
agentic-ai-demo-r1-input agentic-ai-demo-input-tokens 1000
agentic-ai-demo-r1-output agentic-ai-demo-output-tokens 250
agentic-ai-demo-r2-input agentic-ai-demo-input-tokens 2500
agentic-ai-demo-r2-output agentic-ai-demo-output-tokens 600
agentic-ai-demo-r3-input agentic-ai-demo-input-tokens 1500
agentic-ai-demo-r3-output agentic-ai-demo-output-tokens 400
EVENTS

# Deliberately retry one transaction to prove that it cannot be billed twice.
send_event agentic-ai-demo-r1-input agentic-ai-demo-input-tokens 1000

usage_path='/customers/agentic-ai-demo-customer/current_usage?external_subscription_id=agentic-ai-demo-subscription&apply_taxes=false'
printf 'Reconciling usage'
attempt=1
while [ "$attempt" -le 30 ]; do
  usage=$(require_api GET "$usage_path")
  input_units=$(printf '%s' "$usage" | jq -r '[.customer_usage.charges_usage[] | select(.billable_metric.code=="agentic-ai-demo-input-tokens") | .units] | first // "0"')
  output_units=$(printf '%s' "$usage" | jq -r '[.customer_usage.charges_usage[] | select(.billable_metric.code=="agentic-ai-demo-output-tokens") | .units] | first // "0"')
  amount_cents=$(printf '%s' "$usage" | jq -r '.customer_usage.amount_cents // 0')
  if [ "$input_units" = "5000.0" ] && [ "$output_units" = "1250.0" ] && [ "$amount_cents" = "2" ]; then
    printf ' verified\n'
    break
  fi
  printf '.'
  attempt=$((attempt + 1))
  sleep 1
done

[ "$attempt" -le 30 ] || {
  printf '\n' >&2
  printf 'Usage did not reconcile within 30 seconds.\n' >&2
  printf '%s\n' "$usage" | jq . >&2
  exit 1
}

printf '\nLago priced an AI workload locally.\n\n'
printf '  3 AI requests\n'
printf '  5,000 input tokens  x $0.000002 = $0.01\n'
printf '  1,250 output tokens x $0.000008 = $0.01\n'
printf '  Lago usage total                   = $0.02\n\n'
printf 'Verified: Lago returned 5,000 input tokens, 1,250 output tokens, and 2 cents.\n'
printf 'Verified: retrying one transaction did not increase usage.\n'
