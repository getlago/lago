#!/bin/sh

set -eu

BASE_URL=$1
API_KEY=$2
RESPONSE_FILE=$(mktemp "${TMPDIR:-/tmp}/lago-seats-response.XXXXXX")
trap 'rm -f "$RESPONSE_FILE"' EXIT HUP INT TERM

api() {
  method=$1
  path=$2
  payload=${3:-}
  if [ -n "$payload" ]; then
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $API_KEY" \
      -H 'Content-Type: application/json' --data "$payload")
  else
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" -H "Authorization: Bearer $API_KEY")
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
  if curl -fsS "$BASE_URL/features" -H "Authorization: Bearer $API_KEY" >/dev/null 2>&1; then
    printf ' ready\n'
    break
  fi
  printf '.'
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 45 ] || { printf '\nLago did not become ready within 45 seconds.\n' >&2; exit 1; }

metric=$(api POST /billable_metrics '{"billable_metric":{"name":"API calls","code":"seats-api-calls","aggregation_type":"sum_agg","field_name":"calls"}}')
metric_id=$(printf '%s' "$metric" | jq -er '.billable_metric.lago_id')

api POST /features '{"feature":{"name":"Enterprise access","code":"seats-enterprise-access","privileges":[{"code":"sso_enabled","name":"SSO enabled","value_type":"boolean"},{"code":"max_projects","name":"Maximum projects","value_type":"integer"}]}}' >/dev/null
api POST /features '{"feature":{"name":"API access","code":"seats-api-access","privileges":[{"code":"included_calls","name":"Included API calls","value_type":"integer"}]}}' >/dev/null
api POST /add_ons '{"add_on":{"name":"Additional seat","code":"seats-additional-seat","amount_cents":1200,"amount_currency":"USD"}}' >/dev/null

plan_payload=$(jq -n --arg metric "$metric_id" \
  '{plan:{name:"Team API",code:"seats-team-plan",interval:"monthly",amount_cents:2900,amount_currency:"USD",pay_in_advance:true,charges:[{billable_metric_id:$metric,code:"api-overage",charge_model:"graduated",pay_in_advance:false,properties:{graduated_ranges:[{from_value:0,to_value:10000,per_unit_amount:"0",flat_amount:"0"},{from_value:10001,to_value:null,per_unit_amount:"0.001",flat_amount:"0"}]}}]}}')
api POST /plans "$plan_payload" >/dev/null
api POST /plans/seats-team-plan/fixed_charges '{"fixed_charge":{"add_on_code":"seats-additional-seat","code":"extra-seats","charge_model":"standard","pay_in_advance":true,"units":"5","properties":{"amount":"12"}}}' >/dev/null
api POST /plans/seats-team-plan/entitlements '{"entitlements":{"seats-enterprise-access":{"sso_enabled":true,"max_projects":5},"seats-api-access":{"included_calls":10000}}}' >/dev/null

api POST /customers '{"customer":{"external_id":"seats-demo-customer","name":"Seats Demo Customer","currency":"USD"}}' >/dev/null
subscription=$(api POST /subscriptions '{"subscription":{"external_customer_id":"seats-demo-customer","plan_code":"seats-team-plan","external_id":"seats-demo-subscription","billing_time":"anniversary"}}')
event_timestamp=$(printf '%s' "$subscription" | jq -er '.subscription.started_at | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 + 1')
while [ "$(date +%s)" -lt "$event_timestamp" ]; do sleep 1; done

attempt=1
while [ "$attempt" -le 30 ]; do
  invoices=$(api GET /customers/seats-demo-customer/invoices)
  if printf '%s' "$invoices" | jq -e '[.invoices[] | select(.total_amount_cents == 8900)] | length > 0' >/dev/null; then break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 30 ] || { printf 'The $89 base-plus-seats invoice was not found.\n' >&2; exit 1; }

entitlements=$(api GET /subscriptions/seats-demo-subscription/entitlements)
printf '%s' "$entitlements" | jq -e '
  [.entitlements[] | select(.code == "seats-enterprise-access") | .privileges[] | select(.code == "sso_enabled") | .value] == [true] and
  [.entitlements[] | select(.code == "seats-enterprise-access") | .privileges[] | select(.code == "max_projects") | .value] == [5] and
  [.entitlements[] | select(.code == "seats-api-access") | .privileges[] | select(.code == "included_calls") | .value] == [10000]
' >/dev/null

overridden=$(api PATCH /subscriptions/seats-demo-subscription/entitlements '{"entitlements":{"seats-enterprise-access":{"max_projects":25}}}')
printf '%s' "$overridden" | jq -e '
  [.entitlements[] | select(.code == "seats-enterprise-access") | .privileges[] | select(.code == "max_projects") | {value,plan_value,override_value}] == [{value:25,plan_value:5,override_value:25}]
' >/dev/null

event=$(jq -n --argjson timestamp "$event_timestamp" \
  '{event:{transaction_id:"seats-demo-usage-1",external_subscription_id:"seats-demo-subscription",code:"seats-api-calls",timestamp:$timestamp,properties:{calls:15000}}}')
api POST /events "$event" >/dev/null
attempt=1
while [ "$attempt" -le 30 ]; do
  usage=$(api GET '/customers/seats-demo-customer/current_usage?external_subscription_id=seats-demo-subscription&apply_taxes=false')
  if printf '%s' "$usage" | jq -e '
    .customer_usage.amount_cents == 500 and
    [.customer_usage.charges_usage[] | select(.billable_metric.code == "seats-api-calls") | .units | tonumber] == [15000]
  ' >/dev/null; then break; fi
  attempt=$((attempt + 1))
  sleep 1
done
[ "$attempt" -le 30 ] || { printf 'The $5 API overage did not reconcile within 30 seconds.\n' >&2; exit 1; }

printf 'Verified on local Lago: $29 base + five $12 seats = $89 advance invoice.\n'
printf 'Verified: 10,000 included calls, then 5,000 calls at $0.001 = $5 current usage.\n'
printf 'Verified: SSO access and 10,000 included calls on the plan; a subscription override changed max projects from 5 to 25.\n'
printf 'The application must enforce access. This does not test Lago Cloud, collection, or the final usage invoice.\n'
