#!/usr/bin/env bash
# Tear down and reapply the event-derived chain after reshaping a stage in
# sql/04_enrichment.sql (e.g. the 2026-08-23 ranking partition-key fix,
# ROADMAP §0). Written because `setup.sh` alone CANNOT do this:
#
#  1. `CREATE ... IF NOT EXISTS` binds the query BEFORE honoring IF NOT
#     EXISTS, so re-running setup.sh against a reshaped stage fails on the
#     OLD catalog entry instead of no-op'ing.
#  2. Recreating `events_expanded_load` alone is WORSE than useless: a
#     sink-into-table BACKFILLS from its upstream, so it would re-append the
#     entire 32-day `events_enriched` window into `events_expanded` — which
#     is APPEND ONLY and already holds those rows. Every event in the window
#     would be counted twice. The target table must be dropped and recreated
#     with the sink.
#
# Scope: everything downstream of (and including) `events_expanded`. The CDC
# dimensions, `flat_filters`, `events_enriched` and its own load sink are
# left running — no CDC resnapshot, no replication-slot churn.
#
# Usage: ./extra/risingwave/reapply_enrichment.sh [--yes]
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

if [[ "${1:-}" != "--yes" ]]; then
  cat <<'WARN'
This DROPS and rebuilds every event-derived relation from events_expanded
down (usage buckets, wallet triggers, shadows, latency MVs) and REPLAYS the
32-day events_enriched window through them.

Before running, be aware of the replay side effects:

  * ClickHouse `usage_buckets_15m` is a ReplacingMergeTree fed by an UPSERT
    sink keyed on (bucket, dimensions) — replay is idempotent, values are
    replaced, not added. Safe.
  * ClickHouse `events_enriched_rw_shadow` and
    `events_enriched_expanded_rw_shadow` are PLAIN MergeTrees — replay
    DUPLICATES rows. Truncate them (dev) or plan CH-side dedup (prod) before
    the rebuild; this script only warns.
  * `wallet_refresh_triggers` and `usage_realtime_updates` get the full
    replay (~1 trigger per event in the window). Seek the consumer groups to
    the end after the rebuild, or expect a long catch-up.
  * While the chain is down the realtime read path finds no covering
    buckets and falls back to the events store — correct, just slower.

Re-run with --yes to proceed.
WARN
  exit 1
fi

echo "==> Pre-flight: current row counts"
run_psql -c "SELECT 'events_enriched' AS rel, count(*) FROM events_enriched
             UNION ALL SELECT 'events_expanded', count(*) FROM events_expanded
             UNION ALL SELECT 'usage_buckets_15m', count(*) FROM usage_buckets_15m;"

# Teardown: dependents first, leaves -> root. events_expanded is dropped so
# the reapplied sink backfills into an EMPTY append-only table.
echo "==> Tearing down the events_expanded subtree"
run_psql <<'SQL'
DROP SINK IF EXISTS usage_realtime_updates_sink;
DROP SINK IF EXISTS usage_buckets_clickhouse_sink;
DROP SINK IF EXISTS wallet_refresh_triggers_sink;
DROP SINK IF EXISTS events_enriched_expanded_rw_shadow_sink;
-- Legacy names, for an instance last set up before 2026-08-24 (the expanded
-- shadow was a Kafka sink looped back in to compute pipeline_latency_e2e).
DROP SINK IF EXISTS events_enriched_expanded_shadow_sink;

DROP MATERIALIZED VIEW IF EXISTS usage_latency;
DROP MATERIALIZED VIEW IF EXISTS pipeline_latency_e2e;
DROP SOURCE IF EXISTS events_enriched_shadow_loopback;
DROP MATERIALIZED VIEW IF EXISTS pipeline_latency;
DROP MATERIALIZED VIEW IF EXISTS usage_buckets_15m;

DROP SINK IF EXISTS events_expanded_load;
DROP TABLE IF EXISTS events_expanded;
SQL

echo "==> Reapplying the schema (idempotent for everything left standing)"
"$HERE/setup.sh"

echo "==> Post-flight: the invariants the partition-key fix must hold"
run_psql <<'SQL'
-- over-count: more than one row per (event identity, charge). MUST be 0.
SELECT 'extra_rows' AS invariant, coalesce(sum(n - 1), 0) AS value
FROM (
  SELECT organization_id, code, external_subscription_id, event_ts,
         transaction_id, coalesce(charge_id, '') AS cid, count(*) AS n
  FROM events_expanded
  GROUP BY 1,2,3,4,5,6 HAVING count(*) > 1
) d
UNION ALL
-- under-count: enriched events that produced ZERO expanded rows. Expect 0
-- except for events with no matching subscription/charge at enrichment time
-- (the known CDC-race gap, ROADMAP "orphaned-event re-injection").
SELECT 'enriched_without_expanded', count(*)
FROM events_enriched e
WHERE NOT EXISTS (
  SELECT 1 FROM events_expanded x
  WHERE x.organization_id = e.organization_id
    AND x.code = e.code
    AND x.external_subscription_id = e.external_subscription_id
    AND x.event_ts = e.event_ts
    AND x.transaction_id = e.transaction_id
);
SQL

cat <<'DONE'
==> Done.

Remaining manual steps after a rebuild:
  * seek the wallet_refresh_triggers consumer group to the end
  * re-apply persisted system params if the volume was also wiped:
      ALTER SYSTEM SET barrier_interval_ms TO 250;
      ALTER SYSTEM SET sink_decouple TO false;
  * check the streaming graph at http://localhost:5691
DONE
