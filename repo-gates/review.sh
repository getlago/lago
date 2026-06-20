#!/usr/bin/env bash
#
# review.sh - A DIFFERENT agent grades the work (fresh eyes, adversarial).
#
# The gates catch what they were built to catch. A second reviewer with no
# attachment to the code catches the rest - logic bugs, missing tests, security
# smells, half-finished features. Findings land in review-findings.json, which
# gate.sh then reads.
#
# Output: review-findings.json  (array of {severity,file,line,issue,recommendation})
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"
OUT="${ROOT}/review-findings.json"
MAX_TURNS="${MAX_TURNS:-25}"

if ! have claude; then
  printf '%s[FAIL]%s claude CLI not found.\n' "${C_RED}" "${C_RESET}"
  exit 1
fi

# Review the diff vs. main by default; REVIEW_RANGE overrides.
RANGE="${REVIEW_RANGE:-origin/main...HEAD}"
DIFF_HINT="the changes in: ${RANGE}"
git rev-parse origin/main >/dev/null 2>&1 || { RANGE="HEAD"; DIFF_HINT="the current working tree"; }

read -r -d '' REVIEW_PROMPT <<EOF || true
You are a STAFF engineer doing a hostile, fresh-eyes production-readiness review
of the Lago metering/billing deploy repo. You did not write this code. Assume it
is broken until proven otherwise. This software bills enterprise customers, so
correctness, data-integrity and security matter more than style.

Focus on ${DIFF_HINT}, but read whatever context you need.

Look hard for:
- correctness/logic bugs, race conditions, unhandled errors
- billing/data-integrity risks (dropped or double-counted events, money math)
- missing or weak unit tests for the changed code
- security issues (secrets in code, injection, authz gaps)
- deploy footguns (unpinned versions, broken Kamal/Helm/compose, bad health checks)

Do NOT report style nits. Only things that could hurt in production.

Output ONLY a JSON array (no prose, no markdown fences) of objects:
[{"severity":"critical|high|medium|low","file":"path","line":0,"issue":"...","recommendation":"..."}]
If you find nothing serious, output exactly: []
EOF

printf '%s== fresh-eyes review (%s) ==%s\n' "${C_BOLD}" "${RANGE}" "${C_RESET}"
printf '%sThis calls claude -p and bills your Anthropic account.%s\n' "${C_YELLOW}" "${C_RESET}"

raw="$(claude -p "${REVIEW_PROMPT}" --max-turns "${MAX_TURNS}" --permission-mode plan 2>/dev/null || true)"

# Extract the JSON array even if the model wrapped it in prose/fences.
json="$(printf '%s' "${raw}" | sed -n '/\[/,/\]/p')"
[[ -z "${json}" ]] && json="${raw}"

if printf '%s' "${json}" | jq -e 'type=="array"' >/dev/null 2>&1; then
  printf '%s' "${json}" | jq '.' > "${OUT}"
  count="$(jq 'length' "${OUT}")"
  crit="$(jq '[.[]|select(.severity=="critical")]|length' "${OUT}")"
  high="$(jq '[.[]|select(.severity=="high")]|length' "${OUT}")"
  printf '%s[ok]%s wrote %s (%s findings: %s critical, %s high)\n' \
    "${C_GREEN}" "${C_RESET}" "${OUT}" "${count}" "${crit}" "${high}"
  jq -r '.[] | "  [\(.severity)] \(.file):\(.line) - \(.issue)"' "${OUT}" 2>/dev/null || true
else
  printf '%s[warn]%s review did not return valid JSON; saving raw output to %s.raw\n' "${C_YELLOW}" "${C_RESET}" "${OUT}"
  printf '%s' "${raw}" > "${OUT}.raw"
  echo '[]' > "${OUT}"
fi
