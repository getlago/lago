#!/usr/bin/env bash
# Tails TaskManager stdout — where the `print` connector writes.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f docker-compose.flink.yml logs -f --tail="${1:-100}" flink-taskmanager
