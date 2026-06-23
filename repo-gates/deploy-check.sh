#!/usr/bin/env bash
#
# deploy-check.sh - prove the deploy artifacts are valid BEFORE we ship, so a
# production deploy never blows up on a typo. Covers both deploy styles:
#
#   KAMAL  (pinned to 2.11.0)
#     - the kamal version in use is exactly 2.11.0
#     - .kamal/version and Gemfile agree on 2.11.0
#     - config/deploy.yml parses and has the required keys
#     - `kamal config` renders (best effort; needs secrets/registry)
#
#   HELM
#     - `helm lint deploy/helm/lago`
#     - `helm template deploy/helm/lago` renders without error
#
# Tools are found in this order: native binary -> bundler (kamal) -> pinned
# docker image. If none is available the check SKIPs (and FAILs under STRICT,
# e.g. in CI where these MUST run).
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
cd "${ROOT}"

KAMAL_VERSION_REQUIRED="2.11.0"
KAMAL_IMAGE="ghcr.io/basecamp/kamal:${KAMAL_VERSION_REQUIRED}"
HELM_IMAGE="alpine/helm:3.16.2"   # pinned, never :latest
HELM_CHART="deploy/helm/lago"

############################  KAMAL  ##########################################
section "Kamal (required version ${KAMAL_VERSION_REQUIRED})"

# Resolve how we'll run kamal. Echoes a runner prefix or nothing.
KAMAL_RUNNER=""
if have bundle && bundle exec kamal version >/dev/null 2>&1; then
  KAMAL_RUNNER="bundle exec kamal"
elif have kamal; then
  KAMAL_RUNNER="kamal"
elif have docker; then
  if docker image inspect "${KAMAL_IMAGE}" >/dev/null 2>&1; then
    KAMAL_RUNNER="docker run --rm -v ${ROOT}:/workdir -w /workdir ${KAMAL_IMAGE}"
  fi
fi

# .kamal/version pin marker
if [[ -f .kamal/version ]]; then
  v="$(tr -d '[:space:]' < .kamal/version)"
  if [[ "${v}" == "${KAMAL_VERSION_REQUIRED}" ]]; then
    pass ".kamal/version pins ${KAMAL_VERSION_REQUIRED}"
  else
    fail ".kamal/version is '${v}', expected ${KAMAL_VERSION_REQUIRED}"
  fi
else
  fail ".kamal/version marker missing"
fi

# Gemfile pin
if [[ -f Gemfile ]]; then
  if grep -qE "kamal['\"][[:space:]]*,[[:space:]]*['\"](=[[:space:]]*)?${KAMAL_VERSION_REQUIRED//./\\.}" Gemfile; then
    pass "Gemfile pins kamal ${KAMAL_VERSION_REQUIRED}"
  else
    fail "Gemfile does not pin kamal to ${KAMAL_VERSION_REQUIRED}"
  fi
else
  skip "no Gemfile to pin kamal"
fi

# Installed version actually equals 2.11.0
if [[ -n "${KAMAL_RUNNER}" ]]; then
  kver="$(${KAMAL_RUNNER} version 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "${kver}" == "${KAMAL_VERSION_REQUIRED}" ]]; then
    pass "kamal binary reports ${kver}"
  elif [[ -n "${kver}" ]]; then
    fail "kamal binary reports ${kver}, expected ${KAMAL_VERSION_REQUIRED}"
  else
    skip "could not read kamal version"
  fi
else
  skip "kamal not available (install gem 'kamal' 2.11.0, or pull ${KAMAL_IMAGE})"
fi

# config/deploy.yml structure
if [[ -f config/deploy.yml ]]; then
  if have ruby; then
    if ruby -ryaml -e 'YAML.load_file("config/deploy.yml")' >/dev/null 2>&1; then
      pass "config/deploy.yml is valid YAML"
    else
      fail "config/deploy.yml is not valid YAML"
    fi
  fi
  missing=()
  for key in service image servers registry; do
    grep -qE "^${key}:" config/deploy.yml || missing+=("${key}")
  done
  if (( ${#missing[@]} == 0 )); then
    pass "config/deploy.yml has required keys (service, image, servers, registry)"
  else
    fail "config/deploy.yml missing keys: ${missing[*]}"
  fi

  # Render check. `kamal config` resolves env.secret names from .kamal/secrets;
  # supply a throwaway one (placeholders from the example) so it can fully render
  # without real secrets. This is removed immediately and never committed.
  if [[ -n "${KAMAL_RUNNER}" ]]; then
    tmp_secrets=0
    if [[ ! -f .kamal/secrets && -f .kamal/secrets.example ]]; then
      sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=placeholder/' .kamal/secrets.example > .kamal/secrets
      tmp_secrets=1
    fi
    if ${KAMAL_RUNNER} config >.kamal.log 2>&1; then
      pass "kamal config renders"
    else
      if grep -qiE 'no such host|network|registry|connection refused' .kamal.log; then
        skip "kamal config needs registry/network to fully render"
      else
        fail "kamal config errored"
        note "$(tail -n 12 .kamal.log)"
      fi
    fi
    rm -f .kamal.log
    (( tmp_secrets == 1 )) && rm -f .kamal/secrets
  fi
else
  fail "config/deploy.yml missing"
fi

############################  HELM  ###########################################
section "Helm chart (${HELM_CHART})"

HELM_RUNNER=""
if have helm; then
  HELM_RUNNER="helm"
elif have docker && docker image inspect "${HELM_IMAGE}" >/dev/null 2>&1; then
  HELM_RUNNER="docker run --rm -v ${ROOT}:/apps -w /apps ${HELM_IMAGE}"
fi

if [[ ! -d "${HELM_CHART}" ]]; then
  fail "${HELM_CHART} not found"
elif [[ -z "${HELM_RUNNER}" ]]; then
  skip "helm not available (install helm, or pull ${HELM_IMAGE})"
else
  if ${HELM_RUNNER} lint "${HELM_CHART}" >.helm.log 2>&1; then
    pass "helm lint"
  else
    fail "helm lint"
    note "$(tail -n 15 .helm.log)"
  fi
  rm -f .helm.log

  if ${HELM_RUNNER} template lago "${HELM_CHART}" >.helm.log 2>&1; then
    pass "helm template renders"
  else
    fail "helm template"
    note "$(tail -n 15 .helm.log)"
  fi
  rm -f .helm.log
fi

finish "Deploy gate (Kamal + Helm)"
exit $?
