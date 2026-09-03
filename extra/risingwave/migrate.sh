#!/usr/bin/env bash
# Rails-style migrations for the RisingWave pipeline.
#
# State lives IN RisingWave itself: a plain `schema_migrations` user table
# (version PRIMARY KEY, name, checksum, applied_at). That is deliberate — the
# ledger shares the RW state store's fate: wipe the volume and both the schema
# and the record of what was applied disappear together, so they can never
# disagree. Verified on v3.0.2: user-table DML + FLUSH gives read-your-writes.
#
# Model (same split as Rails schema.rb + db/migrate):
#   sql/*.sql        CURRENT STATE — what a fresh install applies (setup.sh).
#                    Keep it up to date when a migration reshapes something.
#   migrations/      DELTAS — numbered, run once, in order, recorded in
#                    `schema_migrations`. A migration is either a .sql file
#                    (applied via psql, ON_ERROR_STOP=1) or a .sh file
#                    (executed with bash; RW_HOST/RW_PORT exported) for
#                    changes that need orchestration: subtree teardown,
#                    ClickHouse DDL, consumer-group seeks.
#
# Commands:
#   ./migrate.sh status          applied / pending / drifted
#   ./migrate.sh up              apply all pending migrations in order
#   ./migrate.sh new <name>      create migrations/NNNN_<name>.sql from template
#   ./migrate.sh baseline        stamp ALL files as applied WITHOUT running them
#                                (for an instance that already has the schema —
#                                setup.sh calls this after a fresh install)
#
# No transactions: RisingWave DDL is not transactional, so a failed migration
# is recorded as NOT applied but may be half-done. Write every migration
# idempotently (DROP ... IF EXISTS before CREATE) so re-running `up` after a
# fix converges instead of erroring.
set -euo pipefail

RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"
export RW_HOST RW_PORT
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIG_DIR="$HERE/migrations"

run_psql() {
  if command -v psql >/dev/null 2>&1; then
    psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -v ON_ERROR_STOP=1 "$@"
  else
    docker exec -i lago_db_dev psql -h risingwave -p 4566 -d dev -U root -v ON_ERROR_STOP=1 "$@"
  fi
}

ensure_state_table() {
  local n
  n="$(run_psql -tAc "SELECT count(*) FROM rw_catalog.rw_tables WHERE name = 'schema_migrations';")"
  [[ "$n" == "0" ]] || return 0
  run_psql -q <<'SQL'
CREATE TABLE schema_migrations (
    version VARCHAR PRIMARY KEY,
    name VARCHAR,
    checksum VARCHAR,
    applied_at TIMESTAMPTZ
);
SQL
}

# Prints "version|checksum" per applied migration.
applied_rows() {
  run_psql -tA -F'|' -c "SELECT version, checksum FROM schema_migrations ORDER BY version;"
}

# migrations/NNNN_name.(sql|sh) -> version is the leading digits.
file_version() { basename "$1" | grep -oE '^[0-9]+'; }
file_checksum() { md5sum "$1" | cut -d' ' -f1; }

record_applied() { # version name checksum
  run_psql -q <<SQL
INSERT INTO schema_migrations (version, name, checksum, applied_at)
VALUES ('$1', '$2', '$3', now());
FLUSH;
SQL
}

migration_files() {
  [[ -d "$MIG_DIR" ]] || return 0
  find "$MIG_DIR" -maxdepth 1 \( -name '[0-9]*.sql' -o -name '[0-9]*.sh' \) | sort
}

cmd_status() {
  ensure_state_table
  declare -A applied
  while IFS='|' read -r v c; do [[ -n "$v" ]] && applied[$v]="$c"; done < <(applied_rows)
  local pending=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    local v; v="$(file_version "$f")"
    if [[ -n "${applied[$v]:-}" ]]; then
      if [[ "${applied[$v]}" == "$(file_checksum "$f")" ]]; then
        echo "  applied  $(basename "$f")"
      else
        echo "  DRIFTED  $(basename "$f")   (file edited after being applied)"
      fi
      unset "applied[$v]"
    else
      echo "  pending  $(basename "$f")"
      pending=$((pending + 1))
    fi
  done < <(migration_files)
  for v in "${!applied[@]}"; do
    echo "  MISSING  version $v is recorded as applied but has no file"
  done
  echo "==> $pending pending"
}

cmd_up() {
  ensure_state_table
  declare -A applied
  while IFS='|' read -r v c; do [[ -n "$v" ]] && applied[$v]="$c"; done < <(applied_rows)
  local ran=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    local v; v="$(file_version "$f")"
    [[ -n "${applied[$v]:-}" ]] && continue
    echo "==> Applying $(basename "$f")"
    case "$f" in
      *.sql) run_psql -f "$f" ;;
      *.sh)  bash "$f" ;;
    esac
    record_applied "$v" "$(basename "$f")" "$(file_checksum "$f")"
    ran=$((ran + 1))
  done < <(migration_files)
  echo "==> Done. $ran migration(s) applied."
}

cmd_baseline() {
  ensure_state_table
  declare -A applied
  while IFS='|' read -r v c; do [[ -n "$v" ]] && applied[$v]="$c"; done < <(applied_rows)
  local stamped=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    local v; v="$(file_version "$f")"
    [[ -n "${applied[$v]:-}" ]] && continue
    record_applied "$v" "$(basename "$f")" "$(file_checksum "$f")"
    echo "  stamped  $(basename "$f")"
    stamped=$((stamped + 1))
  done < <(migration_files)
  echo "==> Baseline: $stamped migration(s) stamped as applied without running."
}

cmd_new() {
  local name="${1:?usage: migrate.sh new <snake_case_name>}"
  mkdir -p "$MIG_DIR"
  local last next
  last="$(migration_files | tail -1 || true)"
  if [[ -n "$last" ]]; then
    next="$(printf '%04d' $((10#$(file_version "$last") + 1)))"
  else
    next="0001"
  fi
  local f="$MIG_DIR/${next}_${name}.sql"
  cat > "$f" <<'TEMPLATE'
-- What / why:
--
-- Checklist (delete once done):
--  [ ] Idempotent: DROP ... IF EXISTS before every CREATE (no transactions in
--      RW — a failed run must converge on retry). Do NOT rely on
--      CREATE IF NOT EXISTS to "update" anything: it binds the OLD definition.
--  [ ] sql/*.sql current-state files updated to match (fresh installs read
--      those, not this file).
--  [ ] Recreated sink? Check the backfill matrix in README "Changing the
--      pipeline" — sink INTO append-only table duplicates rows unless the
--      table is dropped too, or the sink is created FROM an MV with
--      snapshot='false'. Kafka sink replay floods consumers: seek or snapshot='false'.
--  [ ] Dropped/recreated something under usage_buckets_15m? Mind the `ver`
--      last-write-wins trap (README) — guard with a bucket-window floor.
--  [ ] Needs ClickHouse DDL or consumer seeks too? Make this a .sh migration
--      instead and orchestrate the order there.

-- Streaming jobs created below default to ADAPTIVE parallelism (0001).
SET streaming_parallelism = ADAPTIVE;
TEMPLATE
  echo "Created $f"
}

case "${1:-status}" in
  status)   cmd_status ;;
  up)       cmd_up ;;
  new)      shift; cmd_new "$@" ;;
  baseline) cmd_baseline ;;
  *) echo "usage: migrate.sh [status|up|new <name>|baseline]" >&2; exit 1 ;;
esac
