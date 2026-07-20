#!/usr/bin/env bash
set -euo pipefail

ROOT="${BFP_LAGO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

sudo service postgresql start
sudo service redis-server start || redis-server --daemonize yes || true

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = 'lago';" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER lago WITH PASSWORD 'changeme' SUPERUSER;"
else
  sudo -u postgres psql -c "ALTER USER lago WITH PASSWORD 'changeme' SUPERUSER;"
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = 'lago';" | grep -q 1; then
  sudo -u postgres createdb -O lago lago
fi

cd "$ROOT/api"
bundle exec rails db:prepare
echo "DB_PREPARE_DONE"
