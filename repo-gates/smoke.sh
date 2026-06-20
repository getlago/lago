#!/usr/bin/env bash
#
# smoke.sh - the LIVE gate. The hardest lesson from the last repo: code can
# compile, pass unit tests, and merge through CI while the running app returns
# 404 to every request. Static gates never caught it; a real HTTP probe would.
#
# So this boots (optionally) the stack and asserts the API actually ANSWERS.
#
# Usage:
#   ./repo-gates/smoke.sh                 # probe an already-running stack
#   SMOKE_UP=1 ./repo-gates/smoke.sh      # `docker compose up -d` first, then probe
#   API_BASE=http://localhost:3000 ./repo-gates/smoke.sh
#
# The Lago API health endpoint is GET /health on port 3000 (see
# deploy/docker-compose.production.yml healthcheck: curl -f localhost:3000/health).
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

API_BASE="${API_BASE:-http://localhost:3000}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
started=0

cleanup() {
  if (( started == 1 )); then
    note "stopping stack we started..."
    docker compose -f "${COMPOSE_FILE}" down >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if ! have curl; then
  skip "curl not installed - cannot run live smoke test"
  finish "Live smoke gate"; exit $?
fi

if [[ "${SMOKE_UP:-0}" == "1" ]]; then
  if ! have docker; then
    skip "SMOKE_UP=1 but docker not available"
    finish "Live smoke gate"; exit $?
  fi
  section "Booting stack (${COMPOSE_FILE})"
  if docker compose -f "${COMPOSE_FILE}" up -d >/dev/null 2>&1; then
    started=1
    pass "docker compose up -d"
  else
    fail "docker compose up -d failed"
    finish "Live smoke gate"; exit $?
  fi
fi

# Wait for the API health endpoint (up to ~90s).
section "Probing ${API_BASE}/health"
ok=0
for i in $(seq 1 45); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "${API_BASE}/health" 2>/dev/null || echo 000)"
  if [[ "${code}" == "200" ]]; then ok=1; break; fi
  sleep 2
done

if (( ok == 1 )); then
  pass "GET /health -> 200"
  body="$(curl -s "${API_BASE}/health" 2>/dev/null || true)"
  note "body: ${body:0:120}"
else
  # Distinguish "nothing is listening" (env: stack not up) from "up but broken".
  if curl -s -o /dev/null --max-time 3 "${API_BASE}/" 2>/dev/null; then
    fail "stack is up but /health never returned 200 (last code: ${code:-n/a})"
    note "this is exactly the all-404 class of bug; do not ship"
  else
    skip "no server listening at ${API_BASE} (start the stack, or use SMOKE_UP=1)"
  fi
fi

# If the API answers, make sure it's not ONLY answering health (sanity probe).
if (( ok == 1 )); then
  code="$(curl -s -o /dev/null -w '%{http_code}' "${API_BASE}/api/v1" 2>/dev/null || echo 000)"
  # any HTTP answer (even 401/404) means routing works; 000 = dead
  if [[ "${code}" != "000" ]]; then
    pass "API routing responds at /api/v1 (HTTP ${code})"
  else
    fail "API health is 200 but /api/v1 does not respond at all"
  fi
fi

finish "Live smoke gate"
exit $?
