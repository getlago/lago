#!/usr/bin/env bash
# Row-level diff of events_expanded (production) vs events_expanded_v3
# (v3 shadow) over the window the shadow has been running.
#
# Rows are keyed by (event identity, charge). Only events whose
# kafka_timestamp is at least the shadow's first one AND older than a settle
# delay are compared, so rows still in flight do not show up as missing.
#
# Usage: ./extra/risingwave/matching_filter_v3/parity.sh [settle_seconds=30] [sample=20]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

SETTLE="${1:-30}"
SAMPLE="${2:-20}"

run_psql -v settle="$SETTLE" -v sample="$SAMPLE" <<'SQL'

WITH win AS (
    SELECT min(kafka_timestamp) AS lo, now() - (:'settle' || ' seconds')::interval AS hi
    FROM events_expanded_v3
),
prod AS (
    SELECT p.* FROM events_expanded p, win
    WHERE p.kafka_timestamp >= win.lo AND p.kafka_timestamp < win.hi
),
v3 AS (
    SELECT s.* FROM events_expanded_v3 s, win
    WHERE s.kafka_timestamp >= win.lo AND s.kafka_timestamp < win.hi
),
diff AS (
    SELECT
        CASE
            WHEN s.transaction_id IS NULL THEN 'missing_in_v3'
            WHEN p.transaction_id IS NULL THEN 'extra_in_v3'
            WHEN (p.charge_filter_id IS DISTINCT FROM s.charge_filter_id)
              OR (p.charge_filter_updated_at IS DISTINCT FROM s.charge_filter_updated_at)
              OR (p.filters IS DISTINCT FROM s.filters)
              OR (p.grouped_by IS DISTINCT FROM s.grouped_by)
              OR (p.subscription_id IS DISTINCT FROM s.subscription_id)
              OR (p.value IS DISTINCT FROM s.value)
              OR (p.target_wallet_code IS DISTINCT FROM s.target_wallet_code)
            THEN 'mismatch'
            ELSE 'same'
        END AS outcome
    FROM prod p
    FULL OUTER JOIN v3 s
      ON p.organization_id = s.organization_id
     AND p.external_subscription_id = s.external_subscription_id
     AND p.transaction_id = s.transaction_id
     AND p.code = s.code
     AND p.event_ts = s.event_ts
     AND COALESCE(p.charge_id, '') = COALESCE(s.charge_id, '')
)
SELECT outcome, count(*) AS rows FROM diff GROUP BY outcome ORDER BY outcome;

-- A sample of disagreements, to look at by hand.
SELECT
    COALESCE(p.transaction_id, s.transaction_id) AS transaction_id,
    COALESCE(p.charge_id, s.charge_id) AS charge_id,
    p.charge_filter_id AS prod_filter,
    s.charge_filter_id AS v3_filter,
    p.grouped_by AS prod_grouped_by,
    s.grouped_by AS v3_grouped_by
FROM (
    SELECT * FROM events_expanded
    WHERE kafka_timestamp >= (SELECT min(kafka_timestamp) FROM events_expanded_v3)
      AND kafka_timestamp < now() - (:'settle' || ' seconds')::interval
) p
FULL OUTER JOIN (
    SELECT * FROM events_expanded_v3
    WHERE kafka_timestamp < now() - (:'settle' || ' seconds')::interval
) s
  ON p.organization_id = s.organization_id
 AND p.external_subscription_id = s.external_subscription_id
 AND p.transaction_id = s.transaction_id
 AND p.code = s.code
 AND p.event_ts = s.event_ts
 AND COALESCE(p.charge_id, '') = COALESCE(s.charge_id, '')
WHERE p.transaction_id IS NULL OR s.transaction_id IS NULL
   OR (p.charge_filter_id IS DISTINCT FROM s.charge_filter_id)
   OR (p.grouped_by IS DISTINCT FROM s.grouped_by)
LIMIT :sample;
SQL
