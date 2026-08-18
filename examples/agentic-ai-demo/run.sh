#!/bin/sh

set -eu

DEMO_NAME="lago-agentic-ai-demo"
VOLUME_NAME="lago-agentic-ai-demo-data"
UI_PORT="${LAGO_DEMO_UI_PORT:-8080}"
API_PORT="${LAGO_DEMO_API_PORT:-3000}"
UI_PORT_REQUESTED=false
API_PORT_REQUESTED=false
TEMP_DIR=${TMPDIR:-/tmp}
TEMP_DIR=${TEMP_DIR%/}
SECRET_FILE="$TEMP_DIR/lago-agentic-ai-demo-$(id -u).env"
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"

usage() {
  printf '%s\n' \
    "Usage: $0 [--ui-port PORT] [--api-port PORT] [--cleanup]" \
    "" \
    "Runs a local, disposable AI usage-billing demo." \
    "" \
    "Options:" \
    "  --ui-port PORT   Lago UI port (default: $UI_PORT)" \
    "  --api-port PORT  Lago API port (default: $API_PORT)" \
    "  --cleanup        Remove the demo container, volume, and credentials"
}

cleanup_demo() {
  if docker container inspect "$DEMO_NAME" >/dev/null 2>&1; then
    docker rm -f "$DEMO_NAME" >/dev/null
  fi
  if docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    docker volume rm "$VOLUME_NAME" >/dev/null
  fi
  if [ -f "$SECRET_FILE" ]; then
    rm -f "$SECRET_FILE"
  fi
  printf 'Removed the Lago Agentic AI demo container, data volume, and local credentials.\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --ui-port)
      [ "$#" -ge 2 ] || { usage >&2; exit 1; }
      UI_PORT=$2
      UI_PORT_REQUESTED=true
      shift 2
      ;;
    --api-port)
      [ "$#" -ge 2 ] || { usage >&2; exit 1; }
      API_PORT=$2
      API_PORT_REQUESTED=true
      shift 2
      ;;
    --cleanup)
      cleanup_demo
      exit 0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for command_name in docker curl jq openssl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
done

port_is_available() {
  candidate=$1
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import socket,sys; s=socket.socket(); s.bind(("127.0.0.1", int(sys.argv[1]))); s.close()' "$candidate" >/dev/null 2>&1
    return
  fi
  if command -v ruby >/dev/null 2>&1; then
    ruby -rsocket -e 's=TCPServer.new("127.0.0.1", ARGV[0].to_i); s.close' "$candidate" >/dev/null 2>&1
    return
  fi
  if command -v nc >/dev/null 2>&1; then
    ! nc -z 127.0.0.1 "$candidate" >/dev/null 2>&1
    return
  fi
  ! curl -sS --connect-timeout 1 "http://127.0.0.1:$candidate" >/dev/null 2>&1
}

find_available_port() {
  candidate=$1
  limit=$((candidate + 100))
  while [ "$candidate" -le "$limit" ]; do
    if port_is_available "$candidate"; then
      printf '%s' "$candidate"
      return
    fi
    candidate=$((candidate + 1))
  done
  return 1
}

if ! docker info >/dev/null 2>&1; then
  printf 'Docker is installed but the Docker daemon is not available. Start Docker and retry.\n' >&2
  exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
  printf 'Run this script from a Lago repository checkout containing docker-compose.yml.\n' >&2
  exit 1
fi

VERSION=$(sed -n 's/^[[:space:]]*image: getlago\/api:\([^[:space:]]*\).*$/\1/p' "$COMPOSE_FILE" | head -n 1)
if [ -z "$VERSION" ]; then
  printf 'Could not determine the Lago version from docker-compose.yml.\n' >&2
  exit 1
fi
IMAGE="getlago/lago:$VERSION"

container_exists=false
if docker container inspect "$DEMO_NAME" >/dev/null 2>&1; then
  container_exists=true
  existing_image=$(docker container inspect "$DEMO_NAME" --format '{{.Config.Image}}')
  if [ "$existing_image" != "$IMAGE" ]; then
    printf 'The existing %s container uses %s, but this checkout expects %s.\n' "$DEMO_NAME" "$existing_image" "$IMAGE" >&2
    printf 'Run %s --cleanup before creating a new demo.\n' "$0" >&2
    exit 1
  fi
  detected_ui_port=$(docker port "$DEMO_NAME" 80/tcp | head -n 1 | sed 's/.*://')
  detected_api_port=$(docker port "$DEMO_NAME" 3000/tcp | head -n 1 | sed 's/.*://')
  if [ "$UI_PORT_REQUESTED" = true ] && [ "$UI_PORT" != "$detected_ui_port" ]; then
    printf 'The existing demo uses UI port %s, not requested port %s.\n' "$detected_ui_port" "$UI_PORT" >&2
    exit 1
  fi
  if [ "$API_PORT_REQUESTED" = true ] && [ "$API_PORT" != "$detected_api_port" ]; then
    printf 'The existing demo uses API port %s, not requested port %s.\n' "$detected_api_port" "$API_PORT" >&2
    exit 1
  fi
  UI_PORT=$detected_ui_port
  API_PORT=$detected_api_port
fi

if [ "$container_exists" = false ]; then
  if [ "$UI_PORT_REQUESTED" = true ]; then
    port_is_available "$UI_PORT" || { printf 'Requested UI port %s is already in use.\n' "$UI_PORT" >&2; exit 1; }
  else
    UI_PORT=$(find_available_port "$UI_PORT") || { printf 'Could not find an available UI port.\n' >&2; exit 1; }
  fi
  if [ "$API_PORT_REQUESTED" = true ]; then
    port_is_available "$API_PORT" || { printf 'Requested API port %s is already in use.\n' "$API_PORT" >&2; exit 1; }
  else
    API_PORT=$(find_available_port "$API_PORT") || { printf 'Could not find an available API port.\n' >&2; exit 1; }
  fi
  if [ "$UI_PORT" = "$API_PORT" ]; then
    API_PORT=$(find_available_port "$((API_PORT + 1))") || { printf 'Could not find distinct UI and API ports.\n' >&2; exit 1; }
  fi

  if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    printf 'Pulling %s...\n' "$IMAGE"
    docker pull "$IMAGE"
  fi

  umask 077
  api_key=$(openssl rand -hex 24)
  password=$(openssl rand -hex 24)
  printf '%s\n' \
    'LAGO_CREATE_ORG=true' \
    'LAGO_ORG_USER_EMAIL=agentic-ai-demo@example.local' \
    "LAGO_ORG_USER_PASSWORD=$password" \
    'LAGO_ORG_NAME=Agentic AI Demo' \
    "LAGO_ORG_API_KEY=$api_key" \
    "LAGO_API_URL=http://localhost:$API_PORT" \
    "LAGO_FRONT_URL=http://localhost:$UI_PORT" \
    'LAGO_DISABLE_PDF_GENERATION=true' \
    'LAGO_DISABLE_SEGMENT=true' > "$SECRET_FILE"

  printf 'Starting Lago %s...\n' "$VERSION"
  if ! docker run -d \
    --name "$DEMO_NAME" \
    --env-file "$SECRET_FILE" \
    --mount "source=$VOLUME_NAME,target=/data" \
    -p "127.0.0.1:$UI_PORT:80" \
    -p "127.0.0.1:$API_PORT:3000" \
    "$IMAGE" >/dev/null; then
    docker rm -f "$DEMO_NAME" >/dev/null 2>&1 || true
    printf 'Lago could not start. Check that ports %s and %s are available.\n' "$UI_PORT" "$API_PORT" >&2
    exit 1
  fi
else
  if [ ! -f "$SECRET_FILE" ]; then
    printf 'The demo container exists, but its protected credential file is missing: %s\n' "$SECRET_FILE" >&2
    printf 'Run %s --cleanup and start again.\n' "$0" >&2
    exit 1
  fi
  if [ "$(docker container inspect "$DEMO_NAME" --format '{{.State.Running}}')" != "true" ]; then
    docker start "$DEMO_NAME" >/dev/null
  fi
fi

api_key=$(sed -n 's/^LAGO_ORG_API_KEY=//p' "$SECRET_FILE")
BASE_URL="http://127.0.0.1:$API_PORT/api/v1"
RESPONSE_FILE=$(mktemp "$TEMP_DIR/lago-agentic-ai-response.XXXXXX")
trap 'rm -f "$RESPONSE_FILE"' EXIT HUP INT TERM

request() {
  method=$1
  path=$2
  payload=${3:-}

  if [ -n "$payload" ]; then
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $api_key" \
      --data "$payload")
  else
    status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer $api_key")
  fi

  case "$status" in
    2*) cat "$RESPONSE_FILE" ;;
    *)
      printf 'Lago API request failed: %s %s returned %s.\n' "$method" "$path" "$status" >&2
      cat "$RESPONSE_FILE" >&2
      printf '\n' >&2
      return 1
      ;;
  esac
}

printf 'Waiting for the Lago API...\n'
attempt=1
while [ "$attempt" -le 45 ]; do
  if request GET /billable_metrics >/dev/null 2>&1; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done
if [ "$attempt" -gt 45 ]; then
  printf 'Lago did not become ready within 45 seconds. Review: docker logs %s\n' "$DEMO_NAME" >&2
  exit 1
fi

ensure_metric() {
  code=$1
  name=$2
  if metric=$(request GET "/billable_metrics/$code" 2>/dev/null); then
    printf '%s' "$metric"
    return
  fi
  payload=$(jq -n --arg code "$code" --arg name "$name" \
    '{billable_metric:{name:$name,code:$code,aggregation_type:"sum_agg",field_name:"tokens"}}')
  request POST /billable_metrics "$payload"
}

input_metric=$(ensure_metric agentic-ai-demo-input-tokens 'Input tokens')
input_metric_id=$(printf '%s' "$input_metric" | jq -er '.billable_metric.lago_id')
output_metric=$(ensure_metric agentic-ai-demo-output-tokens 'Output tokens')
output_metric_id=$(printf '%s' "$output_metric" | jq -er '.billable_metric.lago_id')

customer_payload=$(jq -n '{customer:{external_id:"agentic-ai-demo-customer",name:"Agentic AI Demo Customer",currency:"USD"}}')
request POST /customers "$customer_payload" >/dev/null

if ! request GET /plans/agentic-ai-demo-plan >/dev/null 2>&1; then
  plan_payload=$(jq -n \
    --arg input_metric_id "$input_metric_id" \
    --arg output_metric_id "$output_metric_id" \
    '{plan:{name:"Agentic AI Demo",code:"agentic-ai-demo-plan",interval:"monthly",amount_cents:0,amount_currency:"USD",pay_in_advance:false,charges:[{billable_metric_id:$input_metric_id,code:"input-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000002"}},{billable_metric_id:$output_metric_id,code:"output-tokens",charge_model:"standard",pay_in_advance:false,properties:{amount:"0.000008"}}]}}')
  request POST /plans "$plan_payload" >/dev/null
fi

subscription_payload=$(jq -n '{subscription:{external_customer_id:"agentic-ai-demo-customer",plan_code:"agentic-ai-demo-plan",external_id:"agentic-ai-demo-subscription",billing_time:"anniversary"}}')
request POST /subscriptions "$subscription_payload" >/dev/null

send_event() {
  transaction_id=$1
  code=$2
  tokens=$3
  payload=$(jq -n \
    --arg transaction_id "$transaction_id" \
    --arg code "$code" \
    --argjson tokens "$tokens" \
    '{event:{transaction_id:$transaction_id,external_subscription_id:"agentic-ai-demo-subscription",code:$code,properties:{tokens:$tokens}}}')

  status=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
    "$BASE_URL/events" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer $api_key" \
    --data "$payload")

  if [ "$status" = "200" ]; then
    return
  fi
  if [ "$status" = "422" ] && jq -e '.error_details.transaction_id[]? == "value_already_exist"' "$RESPONSE_FILE" >/dev/null; then
    return
  fi
  printf 'Event %s failed with HTTP %s.\n' "$transaction_id" "$status" >&2
  cat "$RESPONSE_FILE" >&2
  printf '\n' >&2
  exit 1
}

send_event agentic-ai-demo-r1-input agentic-ai-demo-input-tokens 1000
send_event agentic-ai-demo-r1-output agentic-ai-demo-output-tokens 250
send_event agentic-ai-demo-r2-input agentic-ai-demo-input-tokens 2500
send_event agentic-ai-demo-r2-output agentic-ai-demo-output-tokens 600
send_event agentic-ai-demo-r3-input agentic-ai-demo-input-tokens 1500
send_event agentic-ai-demo-r3-output agentic-ai-demo-output-tokens 400

# A deliberate retry proves that transaction_id prevents double billing.
send_event agentic-ai-demo-r1-input agentic-ai-demo-input-tokens 1000

usage_path='/customers/agentic-ai-demo-customer/current_usage?external_subscription_id=agentic-ai-demo-subscription&apply_taxes=false'
attempt=1
while [ "$attempt" -le 30 ]; do
  usage=$(request GET "$usage_path")
  input_units=$(printf '%s' "$usage" | jq -r '[.customer_usage.charges_usage[] | select(.billable_metric.code=="agentic-ai-demo-input-tokens") | .units] | first // "0"')
  output_units=$(printf '%s' "$usage" | jq -r '[.customer_usage.charges_usage[] | select(.billable_metric.code=="agentic-ai-demo-output-tokens") | .units] | first // "0"')
  usage_amount_cents=$(printf '%s' "$usage" | jq -r '.customer_usage.amount_cents // 0')
  if [ "$input_units" = "5000.0" ] && [ "$output_units" = "1250.0" ] && [ "$usage_amount_cents" = "2" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 1
done

if [ "$attempt" -gt 30 ]; then
  printf 'Usage did not reconcile within 30 seconds. Last response:\n' >&2
  printf '%s\n' "$usage" | jq . >&2
  exit 1
fi

printf '\nLago priced an AI workload locally.\n\n'
printf '  3 AI requests\n'
printf '  5,000 input tokens  x $0.000002 = $0.01\n'
printf '  1,250 output tokens x $0.000008 = $0.01\n'
printf '  Lago usage total                   = $0.02\n\n'
printf 'Verified: Lago returned 5,000 input tokens, 1,250 output tokens, and 2 cents.\n'
printf 'Verified: retrying transaction agentic-ai-demo-r1-input did not increase usage.\n\n'
printf 'Open Lago: http://localhost:%s\n' "$UI_PORT"
printf 'Local API: http://localhost:%s/api/v1\n' "$API_PORT"
printf 'Credentials: %s (mode 600; values not printed)\n' "$SECRET_FILE"
printf 'Cleanup: %s --cleanup\n' "$0"
