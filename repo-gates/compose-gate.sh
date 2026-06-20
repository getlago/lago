#!/usr/bin/env bash
#
# compose-gate.sh - validate the deploy plumbing that ships with the repo:
#   1. docker compose config  - every compose file parses & interpolates
#   2. Dockerfile lint         - hadolint if available (native or docker)
#   3. shell syntax            - bash -n on every *.sh (shellcheck if available)
#
# A broken compose file or a shell script with a syntax error is a production
# outage waiting to happen, and both are cheap to catch here.
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

# --- 1) compose files validate ------------------------------------------------
if have docker && docker compose version >/dev/null 2>&1; then
  while IFS= read -r cf; do
    [[ -z "${cf}" ]] && continue
    # --env-file keeps "variable is not set" warnings from cluttering output;
    # we only care that the file is structurally valid.
    if docker compose -f "${cf}" config -q >.compose.log 2>&1; then
      pass "docker compose config: ${cf}"
    else
      # unset ${VARS} produce warnings but exit 0; a real error exits non-zero
      fail "docker compose config: ${cf}"
      note "$(tail -n 12 .compose.log)"
    fi
    rm -f .compose.log
  done < <(git ls-files '*docker-compose*.yml' 'docker-compose*.yaml' 2>/dev/null || true)
else
  skip "docker compose not available - cannot validate compose files"
fi

# --- 2) Dockerfile lint -------------------------------------------------------
hadolint_one() {
  local df="$1"
  if have hadolint; then
    hadolint --no-fail "${df}" >/dev/null 2>&1 && return 0 || return 0  # advisory
  fi
  return 99
}
if have hadolint; then
  while IFS= read -r df; do
    [[ -z "${df}" ]] && continue
    # Fail only on errors, not style warnings, so the gate stays signal-rich.
    if hadolint --failure-threshold error "${df}" >.hado.log 2>&1; then
      pass "hadolint: ${df}"
    else
      fail "hadolint (error-level): ${df}"
      note "$(tail -n 10 .hado.log)"
    fi
    rm -f .hado.log
  done < <(git ls-files '*Dockerfile' '*Dockerfile.*' 'Dockerfile' 2>/dev/null || true)
else
  skip "hadolint not installed - Dockerfile lint skipped"
fi

# --- 3) shell script syntax ---------------------------------------------------
sh_checked=0
while IFS= read -r sh; do
  [[ -z "${sh}" ]] && continue
  sh_checked=1
  if have shellcheck; then
    if shellcheck -S error "${sh}" >.sc.log 2>&1; then
      pass "shellcheck: ${sh}"
    else
      fail "shellcheck (error-level): ${sh}"
      note "$(tail -n 10 .sc.log)"
    fi
    rm -f .sc.log
  else
    if bash -n "${sh}" >.sc.log 2>&1; then
      pass "bash -n: ${sh}"
    else
      fail "bash -n syntax error: ${sh}"
      note "$(tail -n 10 .sc.log)"
    fi
    rm -f .sc.log
  fi
done < <(git ls-files '*.sh' 2>/dev/null || true)
(( sh_checked == 0 )) && skip "no shell scripts found to check"
[[ "$(have shellcheck && echo y || echo n)" == "n" ]] && (( sh_checked == 1 )) && \
  note "install shellcheck for deeper shell analysis (bash -n only checks syntax)"

finish "Compose / Docker / shell gate"
exit $?
