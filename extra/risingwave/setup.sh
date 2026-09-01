#!/usr/bin/env bash
# Apply the RisingWave schema (sources, CDC tables, MVs, UDFs, sinks).
#
# Usage: ./extra/risingwave/setup.sh
# Requires the dev stack to be up (db, redpanda, risingwave) and the Rails
# migrations to have run (CDC snapshots the Postgres tables).
set -euo pipefail

RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"
SQL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sql"

run_psql() {
  if command -v psql >/dev/null 2>&1; then
    psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -v ON_ERROR_STOP=1 "$@"
  else
    # Fall back to the psql shipped in the Postgres dev container.
    docker exec -i lago_db_dev psql -h risingwave -p 4566 -d dev -U root -v ON_ERROR_STOP=1 "$@"
  fi
}

# ClickHouse serving tables must exist before the RisingWave sinks that
# validate them at CREATE time.
CH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/clickhouse"
for file in "$CH_DIR"/*.sql; do
  echo "==> Applying $(basename "$file") (clickhouse)"
  docker exec -i lago_clickhouse_dev clickhouse-client --password default -n < "$file"
done

for file in "$SQL_DIR"/*.sql; do
  echo "==> Applying $(basename "$file")"
  if command -v psql >/dev/null 2>&1; then
    run_psql -f "$file"
  else
    run_psql < "$file"
  fi
done

# A fresh install applied the CURRENT state (sql/*.sql already contains every
# past migration's outcome), so stamp all migrations as applied without
# running them — same model as Rails' schema load.
"$(dirname "$SQL_DIR")/migrate.sh" baseline

echo "==> Done. Dashboard: http://localhost:5691 — SQL: psql -h $RW_HOST -p $RW_PORT -d dev -U root"
