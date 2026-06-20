#!/usr/bin/env bash
#
# harden.sh - THE INNER LOOP (the fixer).
#
# It does the boring part on repeat: run the judge (verify.sh), and if anything
# is red, hand the failures to Claude Code with one job - "fix the root cause
# until the gates pass, and DON'T touch the gates themselves." Then re-run.
#
# The gates are the judge; Claude is the worker. Claude never gets to declare
# victory - only verify.sh does.
#
#   ROUNDS     how many fix attempts before giving up         (default 3)
#   MAX_TURNS  cap on Claude's tool turns per attempt          (default 30)
#   CLAUDE_FLAGS  extra flags for `claude` (permissions, etc.) (default safe)
#
# WARNING: this calls `claude -p` which bills your Anthropic account. The caps
# exist on purpose. Start small. Best run inside a disposable container/worktree.
#
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

ROUNDS="${ROUNDS:-3}"
MAX_TURNS="${MAX_TURNS:-30}"
# acceptEdits lets Claude edit files without prompting but still refuses scary
# shell. Override with CLAUDE_FLAGS="--dangerously-skip-permissions" in a sandbox.
CLAUDE_FLAGS="${CLAUDE_FLAGS:---permission-mode acceptEdits}"

if ! have claude; then
  printf '%s[FAIL]%s claude CLI not found. Install Claude Code first.\n' "${C_RED}" "${C_RESET}"
  exit 1
fi

run_verify() { STRICT="${STRICT:-0}" bash "${HERE}/verify.sh"; }

read -r -d '' FIX_PROMPT <<'EOF' || true
You are hardening the Lago metering/billing deploy repo to production quality.

The objective gates are the ONLY judge of done. Do this:

1. Run: ./repo-gates/verify.sh
2. Read every [FAIL]. For each, find and fix the ROOT CAUSE in the application
   code, Dockerfiles, compose files, connector configs, Kamal config, or Helm
   chart. Pin any floating dependency to an exact version.
3. Re-run ./repo-gates/verify.sh and repeat until it prints "GREEN".

HARD RULES:
- NEVER edit anything under repo-gates/, and NEVER weaken, skip, or delete a
  gate to make it pass. Fix the real problem instead.
- Do not change version pins to newer "latest"; pin to a specific known-good
  version.
- Keep changes minimal and focused on what the gates demand.
- If a gate is SKIPPED because a tool is missing, leave it - do not fake it.

When ./repo-gates/verify.sh prints GREEN, stop.
EOF

printf '%s== harden.sh ==%s rounds=%s max-turns=%s\n' "${C_BOLD}" "${C_RESET}" "${ROUNDS}" "${MAX_TURNS}"
printf '%sThis calls claude -p and will bill your Anthropic account.%s\n' "${C_YELLOW}" "${C_RESET}"

if run_verify; then
  printf '\n%sAlready GREEN - nothing to harden.%s\n' "${C_GREEN}" "${C_RESET}"
  exit 0
fi

for (( r = 1; r <= ROUNDS; r++ )); do
  printf '\n%s########## fix attempt %d/%d ##########%s\n' "${C_BOLD}${C_BLUE}" "${r}" "${ROUNDS}" "${C_RESET}"
  # shellcheck disable=SC2086
  claude -p "${FIX_PROMPT}" --max-turns "${MAX_TURNS}" ${CLAUDE_FLAGS} || \
    printf '%s(claude exited non-zero on attempt %d)%s\n' "${C_YELLOW}" "${r}" "${C_RESET}"

  printf '\n%s-- re-running the judge --%s\n' "${C_BOLD}" "${C_RESET}"
  if run_verify; then
    printf '\n%s GREEN after %d attempt(s). Review the diff before committing:%s\n' "${C_BOLD}${C_GREEN}" "${r}" "${C_RESET}"
    printf '   git diff\n'
    exit 0
  fi
done

printf '\n%sStill RED after %d attempts. Read the failures above and either fix by\nhand or raise ROUNDS/MAX_TURNS. Do not lower the gates.%s\n' "${C_RED}" "${ROUNDS}" "${C_RESET}"
exit 1
