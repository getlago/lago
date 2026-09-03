#!/usr/bin/env bash
# Prepares the dev Postgres for Flink CDC. Idempotent.
#
# Flink CDC needs more from the database than RisingWave does, and both of
# these are database-side changes with production cost — see ROADMAP Gate 1
# before assuming they are free:
#
#   1. ONE REPLICATION SLOT PER CAPTURED TABLE (plus transient slots during
#      incremental snapshot), where RisingWave uses one shared slot for all
#      six dimension tables.
#   2. REPLICA IDENTITY FULL on every captured table, or the job CRASHES on
#      the first UPDATE. This makes Postgres write the whole old row to WAL
#      on every UPDATE and DELETE.
set -euo pipefail

DB_CONTAINER=${DB_CONTAINER:-lago_db_dev}
PGUSER=${PGUSER:-lago}
PGDATABASE=${PGDATABASE:-lago}
SLOTS=${SLOTS:-20}

psql_c() { docker exec "$DB_CONTAINER" psql -U "$PGUSER" -d "$PGDATABASE" -c "$1"; }

# Tables Flink CDC captures. Keep in sync with sql/01_cdc_dimensions.sql.
TABLES=(billable_metrics subscriptions)

echo "==> REPLICA IDENTITY FULL on: ${TABLES[*]}"
for t in "${TABLES[@]}"; do
  psql_c "ALTER TABLE public.$t REPLICA IDENTITY FULL;" >/dev/null
done

CURRENT=$(docker exec "$DB_CONTAINER" psql -U "$PGUSER" -d "$PGDATABASE" -tAc "show max_replication_slots")
if [[ "$CURRENT" -lt "$SLOTS" ]]; then
  echo "==> raising max_replication_slots $CURRENT -> $SLOTS (requires a db restart)"
  # ALTER SYSTEM cannot run inside a transaction block, so one -c per statement.
  psql_c "ALTER SYSTEM SET max_replication_slots = $SLOTS;" >/dev/null
  psql_c "ALTER SYSTEM SET max_wal_senders = $SLOTS;" >/dev/null
  echo "!! restart the db container, then re-run: lago restart db"
else
  echo "==> max_replication_slots already $CURRENT"
fi

echo "==> current slots:"
psql_c "select slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) as wal_retained from pg_replication_slots order by slot_name;"
