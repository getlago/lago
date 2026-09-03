#!/usr/bin/env bash
# What / why:
#   All streaming jobs were created while the session default pinned
#   parallelism to the core count of the tier they were born on (tables/sources
#   bounded(4), sinks bounded(8), MVs/indexes bounded(64) after the 2026-09-01
#   scale-day widening). Convert everything to ADAPTIVE so jobs use all
#   available cores and rescale automatically on cluster tier changes, instead
#   of keeping relics as the next ceiling. The sql/*.sql current-state files
#   now SET streaming_parallelism = ADAPTIVE, so fresh installs match.
#
#   Idempotent: reads rw_streaming_parallelism and only alters non-adaptive
#   jobs, so a re-run after a partial failure converges. Rescheduling is
#   online but shuffles actor state — prefer off-peak in shared environments.
set -euo pipefail

RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"

run_psql() {
  if command -v psql >/dev/null 2>&1; then
    psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -v ON_ERROR_STOP=1 "$@"
  else
    docker exec -i lago_db_dev psql -h risingwave -p 4566 -d dev -U root -v ON_ERROR_STOP=1 "$@"
  fi
}

run_psql -tA -F'|' -c "SELECT relation_type, name FROM rw_streaming_parallelism WHERE parallelism <> 'adaptive' ORDER BY relation_type, name;" |
while IFS='|' read -r type name; do
  [[ -n "$name" ]] || continue
  case "$type" in
    table)               kw="TABLE" ;;
    "materialized view") kw="MATERIALIZED VIEW" ;;
    sink)                kw="SINK" ;;
    source)              kw="SOURCE" ;;
    index)               kw="INDEX" ;;
    *) echo "!! unknown relation_type '$type' for '$name' — handle manually" >&2; exit 1 ;;
  esac
  echo "==> ALTER $kw \"$name\" SET PARALLELISM = ADAPTIVE"
  run_psql -q -c "ALTER $kw \"$name\" SET PARALLELISM = ADAPTIVE;"
done

remaining="$(run_psql -tAc "SELECT count(*) FROM rw_streaming_parallelism WHERE parallelism <> 'adaptive';")"
if [[ "$remaining" != "0" ]]; then
  echo "!! $remaining job(s) still non-adaptive after migration" >&2
  exit 1
fi
echo "==> All streaming jobs are now ADAPTIVE."
