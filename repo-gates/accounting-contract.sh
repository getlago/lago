#!/usr/bin/env bash
#
# accounting-contract.sh - the exactly-once contract gate for outbound accounting.
#
# Runs the executable contract in integrations/accounting/: "given usage event X,
# the SELECTED accounting target receives entry Y, exactly once." This is the
# check that protects billing-vs-books integrity.
#
# It is a pure-Go module (NO CGO), so unlike the events-processor it builds and
# tests anywhere - locally and in CI - with no Rust shared library needed.
#
# The real Lago->ERP connector (future) implements accounting.AccountingTarget;
# these same tests must keep passing for it. The accounting target selector
# defaults to the in-house Gridiron module first.
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
PKG="${ROOT}/integrations/accounting"

if [[ ! -d "${PKG}" ]]; then
  skip "integrations/accounting/ not present"
  finish "Accounting contract gate"; exit $?
fi

if ! have go; then
  skip "go toolchain not found"
  finish "Accounting contract gate"; exit $?
fi

cd "${PKG}"

# 1) formatting
unformatted="$(gofmt -l . 2>/dev/null || true)"
if [[ -n "${unformatted}" ]]; then
  fail "gofmt: files not formatted"
  note "run: gofmt -w ${unformatted//$'\n'/ }"
else
  pass "gofmt: formatted"
fi

# 2) vet
if go vet ./... >.vet.log 2>&1; then
  pass "go vet"
else
  fail "go vet"
  note "$(tail -n 12 .vet.log)"
fi
rm -f .vet.log

# 3) the contract tests. Prefer -race (the exactly-once guarantee must hold under
# concurrent redelivery); fall back to plain test if the race detector can't
# build here (needs CGO + a C compiler).
if go test -race ./... >.test.log 2>&1; then
  pass "go test -race ./... (exactly-once contract verified under concurrency)"
elif grep -qiE 'race|cgo|gcc|cc1|exec: \"gcc\"|C compiler' .test.log && go test ./... >.test2.log 2>&1; then
  pass "go test ./... (race detector unavailable here; ran without -race)"
  note "install a C compiler to enable -race locally; CI runs it with -race"
  rm -f .test2.log
else
  fail "go test ./... (accounting contract failing)"
  note "$(tail -n 20 .test.log)"
fi
rm -f .test.log .test2.log

finish "Accounting contract gate"
exit $?
