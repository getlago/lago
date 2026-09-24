#!/usr/bin/env bash
# Step 0 of the slim-filters plan: is the per-event cost of stage-1 filter
# matching the MATCHING, or MOVING the candidate array into the UDF?
#
# Runs four batch queries, each calling one UDF N times on the same charge
# (by default the one with the biggest filters_agg) and one real event's
# properties:
#
#   noop_jsonb     receives filters_agg as JSONB, returns 0   -> cost of passing the JSONB
#   matching_filter (production)                              -> passing + matching
#   noop_varchar   receives match_payload as VARCHAR, returns 0 -> cost of passing the slim payload
#   match_filter_position (slim)                              -> passing + matching
#
# Reading: noop_jsonb ~= matching_filter means passing the data IS the cost.
# The two slim rows show what the new path costs on the same inputs.
#
# Needs ../setup.sh applied (flat_filters_slim). The two noop UDFs are
# created for the run and dropped at the end.
#
# Keep `calls` small: a batch query materializes calls x filters_agg in one
# go. 1000 calls on a 556KB row (2502 filters) crashed a local RisingWave
# 3.0.2 standalone; 200 is safe and already gives stable timings.
#
# Reference run (2026-09-24, local, synthetic 2502-filter charge, 200 calls,
# steady state): noop_jsonb ~740ms, matching_filter ~770ms, noop_varchar
# ~60ms, match_filter_position ~70-85ms.
#
# Usage: ./bench/marshalling.sh [calls=200] [charge_id] [properties_json]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib.sh"

CALLS="${1:-200}"
CHARGE="${2:-}"
PROPS="${3:-}"

if [[ -z "$CHARGE" ]]; then
  CHARGE="$(run_psql -tAc "SELECT charge_id FROM flat_filters_agg ORDER BY octet_length(filters_agg::varchar) DESC LIMIT 1;")"
fi
if [[ -z "$PROPS" ]]; then
  # A real, recent event of that charge's metric, so matching walks a
  # realistic path (falls back to '{}' = default bucket if none is found).
  PROPS="$(run_psql -tAc "
    SELECT COALESCE((
      SELECT e.properties::varchar FROM events_enriched e
      JOIN flat_filters_agg f ON f.charge_id = '$CHARGE'
       AND e.organization_id = f.organization_id AND e.code = f.billable_metric_code
      ORDER BY e.kafka_timestamp DESC LIMIT 1), '{}');")"
fi

run_psql -v calls="$CALLS" -v charge="$CHARGE" -v props="$PROPS" <<'SQL'
CREATE FUNCTION IF NOT EXISTS slim_bench_noop_jsonb(filters JSONB, properties JSONB) RETURNS INT
LANGUAGE rust AS $$
fn slim_bench_noop_jsonb(filters: serde_json::Value, properties: serde_json::Value) -> i32 {
    let _ = (filters, properties);
    0
}
$$;

CREATE FUNCTION IF NOT EXISTS slim_bench_noop_varchar(payload VARCHAR, properties JSONB) RETURNS INT
LANGUAGE rust AS $$
fn slim_bench_noop_varchar(payload: &str, properties: serde_json::Value) -> i32 {
    let _ = (payload, properties);
    0
}
$$;

-- Dropped first: a run interrupted before the final DROP must not leave a
-- view pinned to another charge behind.
DROP VIEW IF EXISTS slim_bench_charge;
CREATE VIEW slim_bench_charge AS
SELECT a.charge_id, a.filters_agg, s.match_payload
FROM flat_filters_agg a
JOIN flat_filters_slim s
  ON s.organization_id = a.organization_id AND s.plan_id = a.plan_id
 AND s.billable_metric_code = a.billable_metric_code AND s.charge_id = a.charge_id
WHERE a.charge_id = :'charge';

SELECT
    charge_id,
    jsonb_array_length(filters_agg) AS filters,
    octet_length(filters_agg::varchar) AS filters_agg_bytes,
    octet_length(match_payload) AS match_payload_bytes,
    match_filter_position(match_payload, :'props'::jsonb) AS slim_position,
    matching_filter(filters_agg, :'props'::jsonb) ->> 'charge_filter_id' AS prod_filter_id,
    (filters_agg -> match_filter_position(match_payload, :'props'::jsonb)) ->> 'charge_filter_id' AS slim_filter_id
FROM slim_bench_charge;

\echo 'properties:' :props
\timing on
\echo '--- noop_jsonb (pass filters_agg JSONB, no work)'
SELECT sum(slim_bench_noop_jsonb(f.filters_agg, :'props'::jsonb))
FROM slim_bench_charge f, generate_series(1, :calls) g;

\echo '--- matching_filter (production)'
SELECT count(matching_filter(f.filters_agg, :'props'::jsonb))
FROM slim_bench_charge f, generate_series(1, :calls) g;

\echo '--- noop_varchar (pass match_payload VARCHAR, no work)'
SELECT sum(slim_bench_noop_varchar(f.match_payload, :'props'::jsonb))
FROM slim_bench_charge f, generate_series(1, :calls) g;

\echo '--- match_filter_position (slim)'
SELECT sum(match_filter_position(f.match_payload, :'props'::jsonb))
FROM slim_bench_charge f, generate_series(1, :calls) g;
\timing off

DROP VIEW IF EXISTS slim_bench_charge;
DROP FUNCTION IF EXISTS slim_bench_noop_jsonb(JSONB, JSONB);
DROP FUNCTION IF EXISTS slim_bench_noop_varchar(VARCHAR, JSONB);
SQL
