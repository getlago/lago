#!/usr/bin/env bash
#
# lib.sh - shared helpers for the Lago hardening gates.
#
# Every gate script sources this file. It gives us:
#   - colored PASS / FAIL / SKIP output
#   - per-process pass/fail/skip counters
#   - a `finish` function that prints a summary and returns the right exit code
#
# Exit-code convention used by ALL gate scripts:
#   0 = everything passed
#   1 = at least one real failure (broken code / config)
#   2 = nothing failed, but at least one check was skipped (tool/env missing)
#
# STRICT=1 turns every SKIP into a FAIL. Use it in CI and when you want the
# real "is this actually production ready?" verdict. The whole point of the
# loop is to NOT trust a green that was only green because checks were skipped.
#
# NOTE: this file is SOURCED, so it deliberately does NOT run `set -e`/`set -u`.
# A sourced library must not change shell flags for its caller. The orchestrators
# (verify.sh, gate.sh, ...) intentionally run WITHOUT -e so one failing gate can't
# abort the whole run; each script sets its own flags at the top before sourcing.

# --- colors (off when not a TTY, or when NO_COLOR is set) ---------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_BOLD=$'\033[1m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_BOLD=''
fi

STRICT="${STRICT:-0}"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
BASELINE_COUNT=0
declare -a FAIL_LABELS=()
declare -a SKIP_LABELS=()

# have <command> -> true if the command exists on PATH
have() { command -v "$1" >/dev/null 2>&1; }

# section "Title" -> prints a blue header
section() { printf '\n%s== %s ==%s\n' "${C_BOLD}${C_BLUE}" "$*" "${C_RESET}"; }

# pass / fail / skip "message"  (note: use x=$((x+1)), never ((x++)), under set -e)
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf '  %s[PASS]%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); FAIL_LABELS+=("$*"); printf '  %s[FAIL]%s %s\n' "${C_RED}" "${C_RESET}" "$*"; }
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); SKIP_LABELS+=("$*"); printf '  %s[SKIP]%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*"; }

# baseline: an explicitly-reviewed, PRE-EXISTING item accepted as tracked debt.
# It is printed on every run (never hidden) but does NOT fail the gate, even under
# STRICT - it is an accepted check, not a missing one. NEW violations must use
# fail(); only an entry already in a reviewed allowlist may use baseline().
baseline() { BASELINE_COUNT=$((BASELINE_COUNT + 1)); printf '  %s[BASE]%s %s %s(accepted baseline; pin when able)%s\n' "${C_BLUE}" "${C_RESET}" "$*" "${C_YELLOW}" "${C_RESET}"; }

# note "..." -> indented secondary line (hints, error tails, etc.)
note() { printf '         %s%s%s\n' "${C_YELLOW}" "$*" "${C_RESET}"; }

# finish "Gate name" -> print summary, return 0/1/2 per the convention above.
finish() {
  local name="${1:-gate}"
  local base_seg=""
  (( BASELINE_COUNT > 0 )) && base_seg="$(printf ', %s%d baseline%s' "${C_BLUE}" "${BASELINE_COUNT}" "${C_RESET}")"
  printf '\n%s%s:%s %s%d passed%s, %s%d failed%s, %s%d skipped%s%s\n' \
    "${C_BOLD}" "${name}" "${C_RESET}" \
    "${C_GREEN}" "${PASS_COUNT}" "${C_RESET}" \
    "${C_RED}" "${FAIL_COUNT}" "${C_RESET}" \
    "${C_YELLOW}" "${SKIP_COUNT}" "${C_RESET}" \
    "${base_seg}"

  if (( FAIL_COUNT > 0 )); then
    return 1
  fi
  if (( SKIP_COUNT > 0 )); then
    if [[ "${STRICT}" == "1" ]]; then
      printf '%sSTRICT=1: %d skipped check(s) count as failures.%s\n' "${C_RED}" "${SKIP_COUNT}" "${C_RESET}"
      return 1
    fi
    return 2
  fi
  return 0
}

# repo_root -> absolute path of the repository root (works wherever we are called)
repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
}
