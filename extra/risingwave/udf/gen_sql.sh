#!/usr/bin/env bash
# Assembles sql/03_functions.sql from the unit-tested Rust sources in src/.
# Run after editing src/*.rs (and after `cargo test` passes):
#
#   ./extra/risingwave/udf/gen_sql.sh
#
# Each CREATE FUNCTION body is an independent compilation unit for
# RisingWave's embedded Rust UDF toolchain, so shared helpers (go_fmt.rs) are
# repeated into every body that needs them. The body MUST start with the `fn`
# named like the SQL function (the inline wrapper requires it); helpers follow.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/../sql/03_functions.sql"

body() { # body <entry file> [helper files...]
  cat "$@"
}

{
cat <<'HEADER'
-- GENERATED FILE — DO NOT EDIT BY HAND.
-- Source of truth: extra/risingwave/udf/src/*.rs (cargo test runs the parity
-- suite against the Go events-processor semantics); regenerate with
-- extra/risingwave/udf/gen_sql.sh.
--
-- Embedded RUST UDFs, compiled server-side to WASM by RisingWave (verified
-- on v3.0.2; only std/chrono/rust_decimal/serde_json are allowed here).
-- They replace both the JS UDFs and the stage-1 ranking operators
-- (ROADMAP §0c, 2026-08-28): matching_filter and pick_subscription port the
-- Go processor's MatchingFilter (models/flat_filters.go:180) and
-- FetchSubscription (models/subscriptions.go:26) selection loops, so stage 1
-- resolves dimension fan-out with a scalar in-memory loop instead of
-- materialized per-event ranking state. Property values compare by their
-- plain JSON TEXT (json_text.rs — a deliberate simplification over Go's %v
-- float formatting; decision recorded there and in ROADMAP §0c).
--
-- NULL handling: WASM UDFs are STRICT — a SQL NULL argument short-circuits
-- to a NULL result without calling the function. Call sites COALESCE
-- arguments where the Go code accepts nil (see 04_enrichment.sql).

HEADER

printf 'CREATE FUNCTION IF NOT EXISTS matching_filter(filters JSONB, properties JSONB) RETURNS JSONB\nLANGUAGE rust AS $$\n'
body "$HERE/src/matching_filter.rs" "$HERE/src/json_text.rs"
printf '$$;\n\n'

printf 'CREATE FUNCTION IF NOT EXISTS pick_subscription(subs JSONB, event_ts DOUBLE PRECISION) RETURNS JSONB\nLANGUAGE rust AS $$\n'
body "$HERE/src/pick_subscription.rs"
printf '$$;\n\n'

printf 'CREATE FUNCTION IF NOT EXISTS extract_grouped_by(pricing_group_keys JSONB, properties JSONB, accepts_target_wallet BOOLEAN) RETURNS JSONB\nLANGUAGE rust AS $$\n'
body "$HERE/src/extract_grouped_by.rs" "$HERE/src/json_text.rs"
printf '$$;\n'
} > "$OUT"

echo "wrote $OUT"
