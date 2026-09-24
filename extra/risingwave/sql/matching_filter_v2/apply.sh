#!/usr/bin/env bash
# Apply (or drop) the matching_filter_v2 evaluation objects next to the
# running pipeline. Nothing here touches the v1 objects.
#
#   ./extra/risingwave/sql/matching_filter_v2/apply.sh            dimension + UDF
#   ./extra/risingwave/sql/matching_filter_v2/apply.sh --shadow   + events_expanded_v2 shadow stage
#   ./extra/risingwave/sql/matching_filter_v2/apply.sh --drop     remove everything v2
#
# Then check parity with 04_parity_check.sql. The --shadow stage roughly
# doubles stage-1 work while it runs and backfills ~33 days of events_enriched
# on creation (see 03_events_expanded_v2.sql).
set -euo pipefail

RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_psql() {
  if command -v psql >/dev/null 2>&1; then
    psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -v ON_ERROR_STOP=1 "$@"
  else
    docker exec -i lago_db_dev psql -h risingwave -p 4566 -d dev -U root -v ON_ERROR_STOP=1 "$@"
  fi
}

apply_file() {
  echo "==> Applying $(basename "$1")"
  run_psql < "$1"
}

case "${1:-}" in
  --drop)
    run_psql <<'SQL'
DROP SINK IF EXISTS events_expanded_v2_load;
DROP TABLE IF EXISTS events_expanded_v2;
DROP SINK IF EXISTS flat_filters_agg_v2_load;
DROP INDEX IF EXISTS idx_flat_filters_agg_v2_lookup;
DROP TABLE IF EXISTS flat_filters_agg_v2;
DROP MATERIALIZED VIEW IF EXISTS flat_filters_agg_v2_mv;
DROP FUNCTION IF EXISTS matching_filter_v2(VARCHAR, JSONB);
SQL
    ;;
  --shadow)
    apply_file "$HERE/01_flat_filters_agg_v2.sql"
    apply_file "$HERE/02_functions.sql"
    apply_file "$HERE/03_events_expanded_v2.sql"
    ;;
  "")
    apply_file "$HERE/01_flat_filters_agg_v2.sql"
    apply_file "$HERE/02_functions.sql"
    ;;
  *)
    echo "usage: $0 [--shadow|--drop]" >&2
    exit 1
    ;;
esac
