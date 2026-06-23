#!/usr/bin/env bash
#
# verify.sh - THE JUDGE. One command, one verdict.
#
# This is the only thing allowed to say "production ready". It runs every gate
# and returns non-zero if any of them fail. The hardening loop (harden.sh) and
# CI both call this. If verify.sh is green under STRICT=1, the repo has earned
# it - no opinions, just pass/fail.
#
# Usage:
#   ./repo-gates/verify.sh            # normal: missing tools => SKIP (yellow)
#   STRICT=1 ./repo-gates/verify.sh   # CI/real verdict: SKIP counts as FAIL
#   GATES="go pins" ./repo-gates/verify.sh   # run only some gates
#
set -uo pipefail   # NOTE: no -e here; we WANT to run every gate even if one fails
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

STRICT="${STRICT:-0}"

# gate name -> script
declare -a GATE_ORDER=(pins go accounting mcp connectors compose deploy)
declare -A GATE_SCRIPT=(
  [pins]="check-pins.sh"
  [go]="go-gate.sh"
  [accounting]="accounting-contract.sh"
  [mcp]="mcp-gate.sh"
  [connectors]="connectors-gate.sh"
  [compose]="compose-gate.sh"
  [deploy]="deploy-check.sh"
)
declare -A GATE_DESC=(
  [pins]="Version pinning (no floating deps/images)"
  [go]="Go events-processor (fmt/vet/lint/build/test)"
  [accounting]="Accounting outbound contract (exactly-once)"
  [mcp]="Read-only MCP server (agent tools, GET-only)"
  [connectors]="Redpanda Connect connector configs"
  [compose]="Compose / Dockerfile / shell"
  [deploy]="Kamal 2.11.0 + Helm deploy artifacts"
)

# allow GATES="go pins" to subset
if [[ -n "${GATES:-}" ]]; then
  read -r -a GATE_ORDER <<< "${GATES}"
fi

printf '%s\n' "${C_BOLD}Lago hardening gates - verify.sh${C_RESET}"
printf 'mode: %s\n' "$([[ "${STRICT}" == "1" ]] && echo "STRICT (skips count as failures)" || echo "normal (skips are warnings)")"

declare -A RESULT=()
overall=0

for g in "${GATE_ORDER[@]}"; do
  script="${GATE_SCRIPT[${g}]:-}"
  if [[ -z "${script}" ]]; then
    printf '\n%s[?] unknown gate: %s%s\n' "${C_YELLOW}" "${g}" "${C_RESET}"
    continue
  fi
  printf '\n%s########## %s ##########%s\n' "${C_BOLD}${C_BLUE}" "${GATE_DESC[${g}]}" "${C_RESET}"
  # Run the gate as a child process; honour its 0/1/2 exit convention.
  STRICT="${STRICT}" bash "${HERE}/${script}"
  rc=$?
  case "${rc}" in
    0) RESULT[${g}]="PASS" ;;
    2) RESULT[${g}]="SKIP" ;;
    *) RESULT[${g}]="FAIL"; overall=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Grand summary
# ---------------------------------------------------------------------------
printf '\n%s================ VERDICT ================%s\n' "${C_BOLD}" "${C_RESET}"
for g in "${GATE_ORDER[@]}"; do
  r="${RESULT[${g}]:-?}"
  case "${r}" in
    PASS) c="${C_GREEN}" ;;
    SKIP) c="${C_YELLOW}" ;;
    FAIL) c="${C_RED}" ;;
    *)    c="${C_YELLOW}" ;;
  esac
  printf '  %s%-5s%s  %s\n' "${c}" "${r}" "${C_RESET}" "${GATE_DESC[${g}]:-${g}}"
done

if (( overall == 0 )); then
  printf '\n%s GREEN - all gates passed. %s\n' "${C_BOLD}${C_GREEN}" "${C_RESET}"
  if [[ "${STRICT}" != "1" ]]; then
    printf '%sTip: run STRICT=1 ./repo-gates/verify.sh for the real production verdict (no skips allowed).%s\n' "${C_YELLOW}" "${C_RESET}"
  fi
  exit 0
else
  printf '\n%s RED - fix the FAIL gates above, then re-run. %s\n' "${C_BOLD}${C_RED}" "${C_RESET}"
  exit 1
fi
