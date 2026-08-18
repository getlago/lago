#!/bin/sh

set -eu

DEMO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$DEMO_DIR/../.." && pwd)
COMPOSE_FILE="$DEMO_DIR/compose.yml"
PROJECT_NAME="lago-agentic-ai-demo"
UI_PORT=${LAGO_DEMO_UI_PORT:-8080}
API_PORT=${LAGO_DEMO_API_PORT:-3001}
API_KEY="d3d08c5a7c5944c7b54120921f2fcb77f9c1aa43c78217d9"

usage() {
  printf '%s\n' \
    "Usage: $0 [--cleanup]" \
    "" \
    "Runs a disposable local AI usage-billing demo with Docker Compose." \
    "" \
    "Optional environment variables:" \
    "  LAGO_DEMO_UI_PORT   Lago UI port (default: 8080)" \
    "  LAGO_DEMO_API_PORT  Lago API port (default: 3001)"
}

compose() {
  docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@"
}

case "${1:-}" in
  --cleanup)
    compose down --volumes --remove-orphans
    printf 'Removed the Lago Agentic AI demo containers, network, and data volume.\n'
    exit 0
    ;;
  --help|-h)
    usage
    exit 0
    ;;
  "") ;;
  *)
    usage >&2
    exit 1
    ;;
esac

for command_name in docker curl jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  }
done

docker info >/dev/null 2>&1 || {
  printf 'Docker is installed but the Docker daemon is not available.\n' >&2
  exit 1
}

LAGO_VERSION=$(sed -n 's/^[[:space:]]*image: getlago\/api:\([^[:space:]]*\).*$/\1/p' "$ROOT_DIR/docker-compose.yml" | head -n 1)
[ -n "$LAGO_VERSION" ] || {
  printf 'Could not determine the Lago version from docker-compose.yml.\n' >&2
  exit 1
}
export LAGO_VERSION LAGO_DEMO_UI_PORT="$UI_PORT" LAGO_DEMO_API_PORT="$API_PORT"

printf 'Starting Lago %s with Docker Compose...\n' "$LAGO_VERSION"
if ! compose up -d; then
  printf '\nCould not start the demo. If a port is occupied, retry with for example:\n' >&2
  printf 'LAGO_DEMO_UI_PORT=8081 LAGO_DEMO_API_PORT=3002 %s\n' "$0" >&2
  exit 1
fi

"$DEMO_DIR/seed-and-verify.sh" "http://127.0.0.1:$API_PORT/api/v1" "$API_KEY"

printf '\nOpen Lago: http://localhost:%s\n' "$UI_PORT"
printf 'Local API: http://localhost:%s/api/v1\n' "$API_PORT"
printf 'Cleanup: %s --cleanup\n' "$0"
