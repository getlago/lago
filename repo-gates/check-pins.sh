#!/usr/bin/env bash
#
# check-pins.sh - the "no floating versions" gate.
#
# Why this exists: when dependencies float (package.json "^1.2.3", Docker
# "image:latest", "pnpm@latest", ...) a fresh build can silently pull a newer,
# incompatible version -> "a waterfall of errors". Production must be
# reproducible, so EVERYTHING gets an exact, pinned version.
#
# What it checks:
#   1. package.json   - every dependency must be an EXACT version (no ^ ~ * x latest ranges)
#   2. Dockerfiles    - every FROM has an explicit tag; no :latest, no @latest installs
#   3. compose files  - every image: has an explicit, non-latest tag
#   4. shell scripts  - no `docker run/pull ...:latest`
# (The Kamal config and Helm chart are validated separately by deploy-check.sh.)
#
# Pre-existing upstream offenders are listed in repo-gates/pins-allow.txt so the
# gate is GREEN out of the box (ratchet, don't block), but they're printed as
# tracked debt. New violations always FAIL. STRICT=1 fails the allowlisted ones too.
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"
ALLOW="${HERE}/pins-allow.txt"

# is_allowlisted "<key>" -> true if this exact violation is tracked debt
is_allowlisted() {
  [[ -f "${ALLOW}" ]] || return 1
  grep -qxF "$1" "${ALLOW}" 2>/dev/null
}

# report "<violation key>" "<human message>"
#   - allowlisted -> SKIP (tracked debt), or FAIL under STRICT
#   - otherwise   -> FAIL
report() {
  local key="$1" msg="$2"
  if is_allowlisted "${key}"; then
    if [[ "${STRICT}" == "1" ]]; then
      fail "${msg} [tracked debt, failing under STRICT]"
    else
      skip "${msg} [tracked debt in pins-allow.txt]"
    fi
  else
    fail "${msg}"
  fi
}

# files tracked by git only (don't scan vendored / submodule trees)
git_files() { git ls-files "$@" 2>/dev/null || true; }

# ----------------------------------------------------------------------------
# 1) package.json - exact versions only
# ----------------------------------------------------------------------------
pkg_found=0
while IFS= read -r pj; do
  [[ -z "${pj}" ]] && continue
  case "${pj}" in */node_modules/*) continue;; esac
  pkg_found=1
  if ! have jq; then
    skip "package.json found but jq missing: ${pj}"
    continue
  fi
  # Collect "name@range" for any non-exact semver in deps + devDeps + optional/peer.
  bad="$(jq -r '
    [ (.dependencies // {}), (.devDependencies // {}),
      (.optionalDependencies // {}), (.peerDependencies // {}) ]
    | add // {} | to_entries[]
    | select(.value
        | test("^[0-9]+\\.[0-9]+\\.[0-9]+([-+].*)?$") | not)
    | select(.value | test("^(git|github:|file:|link:|workspace:|npm:.*@[0-9])") | not)
    | "\(.key)@\(.value)"' "${pj}" 2>/dev/null || true)"
  if [[ -n "${bad}" ]]; then
    while IFS= read -r dep; do
      [[ -z "${dep}" ]] && continue
      report "pkg:${pj}:${dep}" "unpinned dependency in ${pj}: ${dep}"
    done <<< "${bad}"
  else
    pass "package.json pinned: ${pj}"
  fi
done < <(git_files '*package.json')

if (( pkg_found == 0 )); then
  pass "no package.json in this checkout (front is an empty submodule) - rule enforced when present"
fi

# ----------------------------------------------------------------------------
# 2) Dockerfiles - explicit FROM tags, no :latest / @latest
# ----------------------------------------------------------------------------
while IFS= read -r df; do
  [[ -z "${df}" ]] && continue
  file_ok=1
  # FROM lines (ignore "AS stage" aliases and references to previous stages)
  while IFS= read -r line; do
    img="$(awk '{print $2}' <<< "${line}")"
    [[ -z "${img}" ]] && continue
    case "${img}" in scratch|"") continue;; esac
    # arg-based tags like ruby:$RUBY_VERSION are considered pinned (ARG has a default)
    if [[ "${img}" == *:latest ]]; then
      report "docker:${df}:${img}" "${df}: FROM ${img} uses :latest"; file_ok=0
    elif [[ "${img}" != *:* && "${img}" != *'$'* ]]; then
      report "docker:${df}:${img}" "${df}: FROM ${img} has no explicit tag"; file_ok=0
    fi
  done < <(grep -iE '^\s*FROM\s+' "${df}" 2>/dev/null | grep -ivE '\sAS\s+|from=' || true)
  # @latest installs (pnpm@latest, npm i -g x@latest, ...)
  if grep -qE '@latest' "${df}" 2>/dev/null; then
    while IFS= read -r hit; do
      report "docker:${df}:@latest:${hit}" "${df}: '@latest' install -> ${hit}"; file_ok=0
    done < <(grep -oE '[A-Za-z0-9_.@/-]+@latest' "${df}" 2>/dev/null | sort -u || true)
  fi
  (( file_ok == 1 )) && pass "Dockerfile pinned: ${df}"
done < <(git_files '*Dockerfile' '*Dockerfile.*' 'Dockerfile')

# ----------------------------------------------------------------------------
# 3) compose files - image: tags pinned
# ----------------------------------------------------------------------------
while IFS= read -r cf; do
  [[ -z "${cf}" ]] && continue
  case "${cf}" in deploy/helm/*) continue;; esac
  file_ok=1
  while IFS= read -r img; do
    [[ -z "${img}" ]] && continue
    case "${img}" in *'${'*) continue;; esac   # env-substituted, pinned via .env
    if [[ "${img}" == *:latest ]]; then
      report "compose:${cf}:${img}" "${cf}: image ${img} uses :latest"; file_ok=0
    elif [[ "${img}" != *:* ]]; then
      report "compose:${cf}:${img}" "${cf}: image ${img} has no tag"; file_ok=0
    fi
  done < <(grep -E '^\s*image:\s*' "${cf}" 2>/dev/null | sed -E 's/^\s*image:\s*//; s/["'\'']//g' | sort -u || true)
  (( file_ok == 1 )) && pass "compose images pinned: ${cf}"
done < <(git_files '*docker-compose*.yml' '*compose*.yaml')

# ----------------------------------------------------------------------------
# 4) shell scripts - docker run / pull with floating image tags
# ----------------------------------------------------------------------------
while IFS= read -r sh; do
  [[ -z "${sh}" ]] && continue
  while IFS= read -r hit; do
    [[ -z "${hit}" ]] && continue
    report "sh:${sh}:${hit}" "${sh}: floating image '${hit}'"
  done < <(grep -vE '^[[:space:]]*#' "${sh}" 2>/dev/null \
            | grep -E '(docker run|docker pull)' \
            | grep -oE '[A-Za-z0-9][A-Za-z0-9._/-]*:latest\b' | sort -u || true)
done < <(git_files '*.sh')

finish "Version-pinning gate"
exit $?
