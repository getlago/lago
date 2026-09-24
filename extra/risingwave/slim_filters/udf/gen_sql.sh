#!/usr/bin/env bash
# Assembles ../sql/01_functions.sql from the unit-tested Rust sources in src/.
# Run after editing src/*.rs (and after `cargo test` passes):
#
#   ./extra/risingwave/slim_filters/udf/gen_sql.sh
#
# Same contract as ../../udf/gen_sql.sh: each CREATE FUNCTION body is an
# independent compilation unit and MUST start with the `fn` named like the
# SQL function; helpers follow in the same file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../sql/01_functions.sql"

{
cat <<'HEADER'
-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/slim_filters/udf/src/*.rs (cargo test
-- runs a parity suite against the production matching_filter); regenerate
-- with extra/risingwave/slim_filters/udf/gen_sql.sh.
--
-- encode_filter_payload runs on the dimension side (CDC churn only) and
-- turns a charge's filters_agg into a compact length-prefixed VARCHAR.
-- match_filter_position runs per (event, charge) on that VARCHAR and returns
-- the winner's position in filters_agg (-1 = default bucket), so the big
-- JSONB never crosses the WASM boundary on the event path.

HEADER

printf 'CREATE FUNCTION IF NOT EXISTS encode_filter_payload(filters JSONB) RETURNS VARCHAR\nLANGUAGE rust AS $$\n'
cat "$HERE/src/encode_filter_payload.rs"
printf '$$;\n\n'

printf 'CREATE FUNCTION IF NOT EXISTS match_filter_position(payload VARCHAR, properties JSONB) RETURNS INT\nLANGUAGE rust AS $$\n'
cat "$HERE/src/match_filter_position.rs"
printf '$$;\n'
} > "$OUT"

echo "wrote $OUT"
