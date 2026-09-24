#!/usr/bin/env bash
# Apply the slim-filters shadow on top of a running production pipeline
# (../setup.sh must have been applied: it reads flat_filters_agg_mv,
# subscriptions_agg, events_enriched and the production UDFs).
#
# Creates only new, suffixed objects; nothing in the production chain is
# touched. Undo with ./teardown.sh.
#
# The shadow stage 1 only processes events with kafka_timestamp >=
# SHADOW_SINCE (default: now). Set it in the past to also process recent
# history, e.g. SHADOW_SINCE='2026-09-24T08:00:00Z'.
#
# Usage: [SHADOW_SINCE=<timestamptz>] ./extra/risingwave/slim_filters/setup.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

SHADOW_SINCE="${SHADOW_SINCE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
echo "==> Shadow processes events from $SHADOW_SINCE"

for file in "$HERE"/sql/*.sql; do
  echo "==> Applying $(basename "$file")"
  run_psql_file "$file" -v shadow_since="$SHADOW_SINCE"
done

echo "==> Done. Compare with: ./extra/risingwave/slim_filters/parity.sh"
