#!/usr/bin/env bash
# Stops the Flink cluster. Checkpoints survive on the named volume.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose -f docker-compose.flink.yml down
