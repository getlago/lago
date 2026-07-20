#!/usr/bin/env bash
# Start Sidekiq inside WSL Ubuntu (no Docker).
set -euo pipefail

ROOT="${BFP_LAGO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

sudo service postgresql start
sudo service redis-server start || redis-server --daemonize yes || true

cd "$ROOT/api"
sed -i 's/\r$//' bin/sidekiq 2>/dev/null || true
exec bundle exec sidekiq
