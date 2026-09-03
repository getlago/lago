#!/usr/bin/env bash
# Drives bench-produce.mjs against the local Redpanda with event shapes taken
# from the live dev catalog, so every event joins a real billable metric and a
# real active subscription (an event whose code has no metric is dropped by
# stage 0's INNER join and would silently deflate the measured throughput).
#
#   ./scripts/bench-load.sh --rate 20000 --duration 60 --ramp 10
#   ./scripts/bench-load.sh --topic events-raw-bench --rate 50000 --duration 120
#
# Shared with the RisingWave side of the A/B on purpose: the two engines must
# be fed by the same producer, at the same rate, on the same box.
set -euo pipefail
cd "$(dirname "$0")/.."

DB_CONTAINER=${DB_CONTAINER:-lago_db_dev}
SHAPES=/tmp/lago-bench-shapes.json
LOADTEST_DIR=$(cd ../risingwave/loadtest && pwd)   # for its node_modules/kafkajs

echo "==> collecting event shapes from ${DB_CONTAINER}"
docker exec -i "$DB_CONTAINER" psql -U lago -d lago -A -t -c "
  -- Up to SUBS_PER_BM subscriptions PER billable metric, not the first 500
  -- rows of the cross product. That distinction decides the whole
  -- measurement: stage 0's temporal join is keyed on (organization_id, code),
  -- so events concentrated on a handful of (org, code) pairs land on a
  -- handful of subtasks and the pipeline measures 2 busy cores out of 8.
  -- The first run of this script did exactly that — 466 of 500 shapes shared
  -- 3 codes, two join subtasks ran at 86%/67% busy and the other six at 1%.
  SELECT json_agg(row_to_json(t))
  FROM (
    SELECT organization_id, code, external_subscription_id, properties
    FROM (
      SELECT bm.organization_id,
             bm.code,
             s.external_id AS external_subscription_id,
             CASE WHEN bm.field_name IS NULL
                  THEN json_build_object('x', '1')
                  ELSE json_build_object(bm.field_name, '1')
             END AS properties,
             row_number() OVER (PARTITION BY bm.id ORDER BY s.id) AS rn
      FROM billable_metrics bm
      JOIN subscriptions s
        ON s.organization_id = bm.organization_id
       AND s.status = 1
      WHERE bm.deleted_at IS NULL
    ) ranked
    WHERE rn <= ${SUBS_PER_BM:-8}
  ) t;" > "$SHAPES"

read -r COUNT KEYS <<<"$(python3 -c "
import json
d = json.load(open('$SHAPES')) or []
print(len(d), len({(x['organization_id'], x['code']) for x in d}))
")"
if [[ "$COUNT" == "0" ]]; then
  echo "!! no (billable metric, active subscription) pairs in the dev catalog" >&2
  exit 1
fi
echo "==> $COUNT shapes over $KEYS distinct (organization_id, code) join keys"
if (( KEYS < 16 )); then
  echo "!! only $KEYS join keys — stage 0 hash-shards on this pair, so fewer keys than"
  echo "   subtasks means the measurement is of a few busy cores, not of the pipeline." >&2
fi

docker run --rm -i \
  --network lago_dev_default \
  -v "$LOADTEST_DIR/node_modules:/node_modules:ro" \
  -v "$PWD/scripts:/scripts:ro" \
  -v "$SHAPES:/shapes.json:ro" \
  -e NODE_PATH=/node_modules \
  node:24-alpine \
  node /scripts/bench-produce.mjs --shapes /shapes.json --brokers redpanda:9092 "$@"
