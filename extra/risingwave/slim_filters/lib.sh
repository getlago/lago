# Shared psql helper, same connection model as ../setup.sh.
RW_HOST="${RW_HOST:-localhost}"
RW_PORT="${RW_PORT:-4566}"

run_psql() {
  if command -v psql >/dev/null 2>&1; then
    psql -h "$RW_HOST" -p "$RW_PORT" -d dev -U root -v ON_ERROR_STOP=1 "$@"
  else
    docker exec -i lago_db_dev psql -h risingwave -p 4566 -d dev -U root -v ON_ERROR_STOP=1 "$@"
  fi
}

# run_psql_file <file> [psql args...]
run_psql_file() {
  local file="$1"; shift
  if command -v psql >/dev/null 2>&1; then
    run_psql "$@" -f "$file"
  else
    run_psql "$@" < "$file"
  fi
}
