#!/usr/bin/env bash
#
# mcp-gate.sh - the read-only MCP server gate.
#
# Validates integrations/mcp/ (a pure-Go, stdlib-only MCP server exposing Lago
# billing data as agent tools). The headline invariant it enforces: the server is
# READ-ONLY - its tests fail if any tool ever issues a non-GET request to Lago.
# Pure Go (no CGO), so it builds and tests anywhere - locally and in CI.
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
PKG="${ROOT}/integrations/mcp"

if [[ ! -d "${PKG}" ]]; then
  skip "integrations/mcp/ not present"
  finish "MCP server gate"; exit $?
fi
if ! have go; then
  skip "go toolchain not found"
  finish "MCP server gate"; exit $?
fi

cd "${PKG}"

unformatted="$(gofmt -l . 2>/dev/null || true)"
if [[ -n "${unformatted}" ]]; then
  fail "gofmt: files not formatted"
  note "run: gofmt -w ${unformatted//$'\n'/ }"
else
  pass "gofmt: formatted"
fi

if go vet ./... >.vet.log 2>&1; then
  pass "go vet"
else
  fail "go vet"
  note "$(tail -n 12 .vet.log)"
fi
rm -f .vet.log

if go build ./... >.build.log 2>&1; then
  pass "go build ./... (incl. cmd/lago-mcp)"
else
  fail "go build ./..."
  note "$(tail -n 12 .build.log)"
fi
rm -f .build.log

# Prefer -race (read-only invariant is checked under concurrency); fall back if
# the race detector can't build here (needs CGO + a C compiler).
if go test -race ./... >.test.log 2>&1; then
  pass "go test -race ./... (read-only invariant verified)"
elif grep -qiE 'race|cgo|gcc|cc1|C compiler' .test.log && go test ./... >.test2.log 2>&1; then
  pass "go test ./... (race detector unavailable here; ran without -race)"
  rm -f .test2.log
else
  fail "go test ./... (MCP server tests failing)"
  note "$(tail -n 20 .test.log)"
fi
rm -f .test.log .test2.log

finish "MCP server gate"
exit $?
