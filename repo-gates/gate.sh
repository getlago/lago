#!/usr/bin/env bash
#
# gate.sh - the FINAL merge-eligibility verdict (the bouncer).
#
# Merge-eligible ==  gates GREEN under STRICT  AND  no unresolved critical/high
# review findings. This is what CI runs and what you check before clicking merge.
# It does not commit or merge anything - that decision stays human.
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"
FINDINGS="${ROOT}/review-findings.json"

# 1) Objective gates, in STRICT mode (skips are not allowed to hide problems).
printf '%s== final gate: objective checks (STRICT) ==%s\n' "${C_BOLD}" "${C_RESET}"
gates_ok=0
if STRICT=1 bash "${HERE}/verify.sh"; then
  gates_ok=1
fi

# 2) Review findings (critical/high block; medium/low are advisory).
printf '\n%s== final gate: review findings ==%s\n' "${C_BOLD}" "${C_RESET}"
crit=0; high=0
if [[ -f "${FINDINGS}" ]] && have jq; then
  crit="$(jq '[.[]|select(.severity=="critical")]|length' "${FINDINGS}" 2>/dev/null || echo 0)"
  high="$(jq '[.[]|select(.severity=="high")]|length' "${FINDINGS}" 2>/dev/null || echo 0)"
  printf 'review-findings.json: %s critical, %s high\n' "${crit}" "${high}"
  jq -r '.[]|select(.severity=="critical" or .severity=="high")|"  [\(.severity)] \(.file):\(.line) - \(.issue)"' "${FINDINGS}" 2>/dev/null || true
else
  printf '%sno review-findings.json found - run ./repo-gates/review.sh first (treating as 0 findings).%s\n' "${C_YELLOW}" "${C_RESET}"
fi

# 3) Verdict
printf '\n%s================ MERGE VERDICT ================%s\n' "${C_BOLD}" "${C_RESET}"
blockers=0
[[ "${gates_ok}" == "1" ]] || { printf '  %s[BLOCK]%s objective gates are not GREEN under STRICT\n' "${C_RED}" "${C_RESET}"; blockers=1; }
(( crit > 0 )) && { printf '  %s[BLOCK]%s %s unresolved CRITICAL review finding(s)\n' "${C_RED}" "${C_RESET}" "${crit}"; blockers=1; }
(( high > 0 )) && { printf '  %s[BLOCK]%s %s unresolved HIGH review finding(s)\n' "${C_RED}" "${C_RESET}" "${high}"; blockers=1; }

if (( blockers == 0 )); then
  printf '\n%s MERGE-ELIGIBLE - gates green, no critical/high findings. Final call is yours.%s\n' "${C_BOLD}${C_GREEN}" "${C_RESET}"
  exit 0
else
  printf '\n%s NOT MERGE-ELIGIBLE - resolve the blockers above.%s\n' "${C_BOLD}${C_RED}" "${C_RESET}"
  exit 1
fi
