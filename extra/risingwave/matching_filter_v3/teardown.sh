#!/usr/bin/env bash
# Drop every matching_filter v3 shadow object, in dependency order. The
# production pipeline is left untouched.
#
# Usage: ./extra/risingwave/matching_filter_v3/teardown.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

run_psql <<'SQL'
DROP SINK IF EXISTS events_expanded_v3_load;
DROP TABLE IF EXISTS events_expanded_v3;
DROP SINK IF EXISTS filter_lookup_positions_load;
DROP TABLE IF EXISTS filter_lookup_positions;
DROP MATERIALIZED VIEW IF EXISTS filter_lookup_positions_mv;
DROP SINK IF EXISTS filter_lookup_load;
DROP TABLE IF EXISTS filter_lookup;
DROP MATERIALIZED VIEW IF EXISTS filter_lookup_mv;
DROP INDEX IF EXISTS idx_filter_lookup_charges_lookup;
DROP SINK IF EXISTS filter_lookup_charges_load;
DROP TABLE IF EXISTS filter_lookup_charges;
DROP MATERIALIZED VIEW IF EXISTS filter_lookup_charges_mv;
DROP FUNCTION IF EXISTS filter_lookup_event_keys(JSONB, JSONB);
DROP FUNCTION IF EXISTS filter_lookup_expand(JSONB);
DROP FUNCTION IF EXISTS filter_lookup_plan(JSONB);
SQL

echo "==> matching_filter v3 shadow removed."
