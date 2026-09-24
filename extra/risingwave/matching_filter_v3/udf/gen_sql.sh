#!/usr/bin/env bash
# Assembles ../sql/01_functions.sql from the unit-tested Rust sources in src/.
# Run after editing src/*.rs (and after `cargo test` passes):
#
#   ./extra/risingwave/matching_filter_v3/udf/gen_sql.sh
#
# Same contract as ../../udf/gen_sql.sh: each CREATE FUNCTION body is an
# independent compilation unit and MUST start with the `fn` named like the
# SQL function; shared helpers are repeated into every body that needs them.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../sql/01_functions.sql"

{
cat <<'HEADER'
-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/matching_filter_v3/udf/src/*.rs (cargo
-- test runs a parity suite against the production matching_filter);
-- regenerate with extra/risingwave/matching_filter_v3/udf/gen_sql.sh.
--
-- filter_lookup_plan and filter_lookup_expand run on the dimension side (CDC
-- churn only): they turn a charge's filters_agg into its shapes and one
-- lookup key per (filter, value combination). filter_lookup_event_keys runs
-- per (event, charge) on small inputs (the charge's shapes and the event
-- properties) and returns the event's lookup key per shape, so the filter
-- list never crosses the WASM boundary on the event path.

HEADER

printf 'CREATE FUNCTION IF NOT EXISTS filter_lookup_plan(filters_agg JSONB) RETURNS JSONB\nLANGUAGE rust AS $$\n'
cat "$HERE/src/filter_lookup_plan.rs" "$HERE/src/flv3_common.rs"
printf '$$;\n\n'

printf 'CREATE FUNCTION IF NOT EXISTS filter_lookup_expand(filters JSONB) RETURNS JSONB\nLANGUAGE rust AS $$\n'
cat "$HERE/src/filter_lookup_expand.rs" "$HERE/src/flv3_common.rs"
printf '$$;\n\n'

printf 'CREATE FUNCTION IF NOT EXISTS filter_lookup_event_keys(shapes JSONB, properties JSONB) RETURNS VARCHAR[]\nLANGUAGE rust AS $$\n'
cat "$HERE/src/filter_lookup_event_keys.rs" "$HERE/src/flv3_common.rs" "$HERE/../../udf/src/json_text.rs"
printf '$$;\n'
} > "$OUT"

echo "wrote $OUT"
