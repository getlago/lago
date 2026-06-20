#!/usr/bin/env bash
#
# go-gate.sh - unit-test + static-analysis gate for the Go events-processor.
#
# IMPORTANT (the "honest judge" rule):
#   The events-processor links a Rust shared library (libexpression_go.so) via
#   CGO. Its own CLAUDE.md says a bare `go build` / `go test` will NOT work
#   locally for that reason. So a naive gate would falsely report green.
#
#   This gate therefore tells the difference between:
#     * a REAL failure   -> compile error in our code, or a failing test  -> FAIL
#     * an ENV limitation -> the CGO lib isn't built in this sandbox       -> SKIP
#
#   In CI the lib IS built (see .github/workflows/events-processor-tests.yml),
#   so run with STRICT=1 there and the tests execute for real.
#
#   Opt into a real, containerized test run anywhere with:
#       GO_TEST_IN_DOCKER=1 ./repo-gates/go-gate.sh
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
SVC="${ROOT}/events-processor"

if [[ ! -d "${SVC}" ]]; then
  skip "events-processor/ not present"
  finish "Go events-processor gate"; exit $?
fi

cd "${SVC}"

# Treat linker/CGO errors about the expression lib as an ENV skip, not a failure.
is_cgo_env_error() {
  grep -qiE 'expression_go|expression-go|-lexpression|libexpression|cannot find -l|ld: ' "$1"
}

# 1) gofmt - pure formatting, needs no build, so it ALWAYS runs.
if have gofmt; then
  unformatted="$(gofmt -l . 2>/dev/null || true)"
  if [[ -n "${unformatted}" ]]; then
    fail "gofmt: files are not formatted"
    note "run: gofmt -w ${unformatted//$'\n'/ }"
  else
    pass "gofmt: all files formatted"
  fi
else
  skip "gofmt not found"
fi

build_ok=0
if ! have go; then
  skip "go toolchain not found"
else
  # 2) go build (this is where the CGO lib is needed)
  if go build ./... >.go-build.log 2>&1; then
    pass "go build ./..."
    build_ok=1
  else
    if is_cgo_env_error .go-build.log; then
      skip "go build: CGO lib libexpression_go.so not installed in this env"
      note "this is expected in a bare sandbox; CI builds it and runs for real"
    else
      fail "go build ./..."
      note "$(tail -n 15 .go-build.log)"
    fi
  fi
  rm -f .go-build.log

  # 3) go vet + 4) tests only make sense once the package compiles
  if (( build_ok == 1 )); then
    if go vet ./... >.go-vet.log 2>&1; then
      pass "go vet ./..."
    else
      fail "go vet ./..."
      note "$(tail -n 15 .go-vet.log)"
    fi
    rm -f .go-vet.log

    if go test ./... >.go-test.log 2>&1; then
      pass "go test ./..."
    else
      fail "go test ./... (unit tests failing)"
      note "$(tail -n 20 .go-test.log)"
    fi
    rm -f .go-test.log
  fi
fi

# 5) golangci-lint - some linters need a successful build; only run if we have it.
if have golangci-lint && (( build_ok == 1 )); then
  if golangci-lint run ./... >.golangci.log 2>&1; then
    pass "golangci-lint"
  else
    fail "golangci-lint"
    note "$(tail -n 20 .golangci.log)"
  fi
  rm -f .golangci.log
elif have golangci-lint; then
  skip "golangci-lint (skipped: package did not build in this env)"
fi

# 6) Optional: real tests inside the dev container (needs Docker + the dev image).
if [[ "${GO_TEST_IN_DOCKER:-0}" == "1" ]]; then
  if have docker && [[ -f "${ROOT}/docker-compose.dev.yml" ]]; then
    if docker compose -f "${ROOT}/docker-compose.dev.yml" run --rm events-processor go test ./... ; then
      pass "go test ./... (in docker dev container)"
    else
      fail "go test ./... (in docker dev container)"
    fi
  else
    skip "GO_TEST_IN_DOCKER=1 but docker / docker-compose.dev.yml unavailable"
  fi
fi

finish "Go events-processor gate"
exit $?
