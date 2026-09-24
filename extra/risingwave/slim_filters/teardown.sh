#!/usr/bin/env bash
# Drop every slim-filters shadow object, in dependency order. The production
# pipeline is left untouched.
#
# Usage: ./extra/risingwave/slim_filters/teardown.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

run_psql <<'SQL'
DROP SINK IF EXISTS events_expanded_slim_load;
DROP TABLE IF EXISTS events_expanded_slim;
DROP INDEX IF EXISTS idx_flat_filters_slim_lookup;
DROP SINK IF EXISTS flat_filters_slim_load;
DROP TABLE IF EXISTS flat_filters_slim;
DROP MATERIALIZED VIEW IF EXISTS flat_filters_slim_mv;
DROP FUNCTION IF EXISTS match_filter_position(VARCHAR, JSONB);
DROP FUNCTION IF EXISTS encode_filter_payload(JSONB);
SQL

echo "==> Slim-filters shadow removed."
