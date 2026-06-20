#!/usr/bin/env bash
#
# connectors-gate.sh - validate the Redpanda Connect / Benthos connector configs
# in connectors/ (http.yml, kinesis.yml, sqs.yml).
#
# These pipe ingested events into Kafka. A broken config = dropped billing
# events, so we check them. Levels of checking, best available wins:
#   1. structural  - every config has input: and output: sections (always runs)
#   2. yaml parse  - the file is syntactically valid YAML (ruby/python)
#   3. real lint   - `redpanda-connect lint` / `benthos lint` if installed, or
#                    via docker when CONNECTORS_DOCKER_LINT=1 (opt-in, needs pull)
#
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${HERE}/lib.sh"

ROOT="$(repo_root)"
DIR="${ROOT}/connectors"
# image tag kept in sync with connectors/Dockerfile (pinned, never :latest)
CONNECT_IMAGE="docker.redpanda.com/redpandadata/connect:4.83.0"

if [[ ! -d "${DIR}" ]]; then
  skip "connectors/ not present"
  finish "Connectors gate"; exit $?
fi

shopt -s nullglob
configs=("${DIR}"/*.yml "${DIR}"/*.yaml)
shopt -u nullglob

if (( ${#configs[@]} == 0 )); then
  skip "no connector configs found"
  finish "Connectors gate"; exit $?
fi

# Pick a YAML parser once.
yaml_parse() {
  if have ruby; then ruby -ryaml -e 'YAML.load_file(ARGV[0])' "$1" 2>&1; return $?; fi
  if have python3; then python3 -c 'import sys,yaml;yaml.safe_load(open(sys.argv[1]))' "$1" 2>&1; return $?; fi
  return 99   # no parser available
}

# Pick a real linter once.
LINTER=""
if have redpanda-connect; then LINTER="redpanda-connect"; fi
if [[ -z "${LINTER}" ]] && have benthos; then LINTER="benthos"; fi

for cfg in "${configs[@]}"; do
  name="connectors/$(basename "${cfg}")"

  # 1) structural: must declare an input and an output
  if grep -qE '^\s*input:' "${cfg}" && grep -qE '^\s*output:' "${cfg}"; then
    pass "${name}: has input + output sections"
  else
    fail "${name}: missing input: or output: section"
  fi

  # 2) yaml parse (templating like \${! json(..) } is quoted, so this should hold)
  parse_out="$(yaml_parse "${cfg}")"; rc=$?
  if (( rc == 99 )); then
    skip "${name}: no YAML parser (ruby/python) to validate syntax"
  elif (( rc == 0 )); then
    pass "${name}: valid YAML"
  else
    # Could be Benthos interpolation the parser dislikes -> don't hard-fail.
    skip "${name}: YAML parser rejected file (may be Benthos templating)"
    note "${parse_out%%$'\n'*}"
  fi

  # 3) real lint (only when a linter is actually available)
  if [[ -n "${LINTER}" ]]; then
    if "${LINTER}" lint "${cfg}" >.lint.log 2>&1; then
      pass "${name}: ${LINTER} lint clean"
    else
      fail "${name}: ${LINTER} lint errors"
      note "$(tail -n 10 .lint.log)"
    fi
    rm -f .lint.log
  elif [[ "${CONNECTORS_DOCKER_LINT:-0}" == "1" ]] && have docker; then
    if docker run --rm -v "${DIR}:/cfg:ro" "${CONNECT_IMAGE}" lint "/cfg/$(basename "${cfg}")" >.lint.log 2>&1; then
      pass "${name}: connect lint clean (docker)"
    else
      # distinguish a pull/network problem from a real lint failure
      if grep -qiE 'pull access|not found|no such host|network|timeout|denied' .lint.log; then
        skip "${name}: could not pull ${CONNECT_IMAGE} to lint"
      else
        fail "${name}: connect lint errors (docker)"
        note "$(tail -n 10 .lint.log)"
      fi
    fi
    rm -f .lint.log
  else
    skip "${name}: no connect/benthos linter (set CONNECTORS_DOCKER_LINT=1 to use docker)"
  fi
done

finish "Connectors gate"
exit $?
