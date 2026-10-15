#!/bin/sh

set -eu

BASE_URL=$1
API_KEY=$2
RESPONSE_FILE=$(mktemp "${TMPDIR:-/tmp}/lago-hybrid-ai-response.XXXXXX")
trap 'rm -f "$RESPONSE_FILE"' EXIT HUP INT TERM

api() {
  method=$1
  path=$2
  payload=${3:-}
  if [ -n "$payload" ]; then
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $API_KEY" \
      -H 'Content-Type: application/json' --data "$payload")
  else
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $API_KEY")
  fi
  case "$status" in
    2*) cat "$RESPONSE_FILE" ;;
    *)
      printf 'Lago API request failed: HTTP %s %s %s\n' "$status" "$method" "$path" >&2
      cat "$RESPONSE_FILE" >&2
      printf '\n' >&2
      exit 1
      ;;
  esac
}

printf 'Waiting for the Lago API'
attempt=1
while [ "$attempt" -le 45 ]; do
  if curl -fsS "$BASE_URL/billable_metrics" -H "Authorization: Bearer $API_KEY" >/dev/null 2>&1; then
    printf ' ready\n'
    break
  fi
  printf '.'
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 45 ] || { printf '\nLago did not become ready within 45 seconds.\n' >&2; exit 1; }

metric=$(api POST /billable_metrics '{"billable_metric":{"name":"Hybrid AI tokens","code":"hybrid-ai-tokens","aggregation_type":"sum_agg","field_name":"tokens","filters":[{"key":"model","values":["model_a","model_b"]}]}}')
metric_id=$(printf '%s' "$metric" | jq -er '.billable_metric.lago_id')
api POST /customers '{"customer":{"external_id":"hybrid-ai-customer","name":"Hybrid AI Customer","currency":"USD"}}' >/dev/null

plan_payload=$(jq -n --arg metric "$metric_id" \
  '{plan:{name:"Hybrid AI API",code:"hybrid-ai-plan",interval:"monthly",amount_cents:4900,amount_currency:"USD",pay_in_advance:false,charges:[{billable_metric_id:$metric,code:"model-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000004"},filters:[{values:{model:["model_a"]},properties:{amount:"0.000004"}},{values:{model:["model_b"]},properties:{amount:"0.000008"}}]}]}}')
plan=$(api POST /plans "$plan_payload")
printf '%s' "$plan" | jq -e '.plan.amount_cents == 4900 and (.plan.charges[0].filters | length) == 2' >/dev/null

subscription=$(api POST /subscriptions '{"subscription":{"external_customer_id":"hybrid-ai-customer","plan_code":"hybrid-ai-plan","external_id":"hybrid-ai-subscription","billing_time":"anniversary"}}')
event_timestamp=$(printf '%s' "$subscription" | jq -er '.subscription.started_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 + 1')
while [ "$(date +%s)" -lt "$event_timestamp" ]; do sleep 1; done
api POST /wallets '{"wallet":{"external_customer_id":"hybrid-ai-customer","name":"AI usage credits","code":"hybrid-ai-usage","rate_amount":"1","granted_credits":"2","applies_to":{"fee_types":["charge"],"billable_metric_codes":["hybrid-ai-tokens"]}}}' >/dev/null

send_event() {
  model=$1
  event=$(jq -n --arg model "$model" --argjson timestamp "$event_timestamp" \
    '{event:{transaction_id:("hybrid-ai-"+$model),external_subscription_id:"hybrid-ai-subscription",code:"hybrid-ai-tokens",timestamp:$timestamp,properties:{tokens:100000,model:$model}}}')
  status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
    "$BASE_URL/events" -H "Authorization: Bearer $API_KEY" \
    -H 'Content-Type: application/json' --data "$event")
  [ "$status" = 200 ] && return
  if [ "$status" = 422 ] && jq -e '.error_details.transaction_id[]? == "value_already_exist"' "$RESPONSE_FILE" >/dev/null; then return; fi
  printf 'Event %s failed with HTTP %s.\n' "$model" "$status" >&2
  cat "$RESPONSE_FILE" >&2
  exit 1
}

send_event model_a
send_event model_b
send_event model_a

usage_path='/customers/hybrid-ai-customer/current_usage?external_subscription_id=hybrid-ai-subscription&apply_taxes=false'
attempt=1
while [ "$attempt" -le 30 ]; do
  usage=$(api GET "$usage_path")
  if printf '%s' "$usage" | jq -e '
    .customer_usage.amount_cents == 120 and
    ([.customer_usage.charges_usage[] | select(.billable_metric.code == "hybrid-ai-tokens") | .units | tonumber] | add) == 200000 and
    ([.customer_usage.charges_usage[].filters[] | select(.values.model == ["model_a"]) | .amount_cents] | add) == 40 and
    ([.customer_usage.charges_usage[].filters[] | select(.values.model == ["model_b"]) | .amount_cents] | add) == 80
  ' >/dev/null; then break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 30 ] || { printf 'Model-specific usage did not reconcile within 30 seconds.\n' >&2; exit 1; }

attempt=1
while [ "$attempt" -le 30 ]; do
  wallet=$(api GET /customers/hybrid-ai-customer/wallets/hybrid-ai-usage)
  if printf '%s' "$wallet" | jq -e '.wallet.credits_ongoing_balance | tonumber == 0.8' >/dev/null; then break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 30 ] || { printf 'The scoped credit balance did not reconcile within 30 seconds.\n' >&2; exit 1; }

# A separate subscription verifies that the same usage-only wallet scope does
# not pay a monthly base invoice. It is billed in advance to make the invoice
# visible without advancing the clock by one month.
api POST /customers '{"customer":{"external_id":"hybrid-base-customer","name":"Hybrid Base Customer","currency":"USD"}}' >/dev/null
api POST /wallets '{"wallet":{"external_customer_id":"hybrid-base-customer","name":"AI usage credits","code":"hybrid-base-usage","rate_amount":"1","granted_credits":"2","applies_to":{"fee_types":["charge"],"billable_metric_codes":["hybrid-ai-tokens"]}}}' >/dev/null
base_plan=$(jq -n --arg metric "$metric_id" \
  '{plan:{name:"Hybrid base invoice check",code:"hybrid-base-plan",interval:"monthly",amount_cents:4900,amount_currency:"USD",pay_in_advance:true,charges:[{billable_metric_id:$metric,code:"model-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000004"}}]}}')
api POST /plans "$base_plan" >/dev/null
api POST /subscriptions '{"subscription":{"external_customer_id":"hybrid-base-customer","plan_code":"hybrid-base-plan","external_id":"hybrid-base-subscription","billing_time":"anniversary"}}' >/dev/null
attempt=1
while [ "$attempt" -le 30 ]; do
  invoices=$(api GET /customers/hybrid-base-customer/invoices)
  if printf '%s' "$invoices" | jq -e '[.invoices[] | select(.total_amount_cents == 4900)] | length > 0' >/dev/null; then break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 30 ] || { printf 'The $49 base invoice was not found.\n' >&2; exit 1; }

printf 'Verified on local Lago: $49 monthly plan, $0.40 model A usage, $0.80 model B usage, and $0.80 of $2 usage-only credits remaining.\n'
printf 'A separate advance-billed subscription confirmed its $49 base invoice remained payable with the same credit scope.\n'
printf 'Verified: retrying the same transaction ID and timestamp did not add usage.\n'
printf 'This does not test payment collection, paid credit purchases, Lago Cloud, or the final usage invoice.\n'
