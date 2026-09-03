#!/usr/bin/env bash
# Starts the local Flink cluster on the lago dev network.
#
# Requires the lago dev stack to be up (the network `lago_dev_default` and
# the `redpanda` service must exist).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! docker network inspect lago_dev_default >/dev/null 2>&1; then
  echo "!! network lago_dev_default not found — start the lago dev stack first (\`lago up -d\`)" >&2
  exit 1
fi

# The checkpoint volume is created root-owned but the Flink image runs as uid
# 9999; without this the JobManager dies at "Failed to create directory for
# shared state". Idempotent, so it just runs every time.
docker volume create lago_flink_flink_checkpoints >/dev/null
docker run --rm -v lago_flink_flink_checkpoints:/cp alpine:3 chown -R 9999:9999 /cp

docker compose -f docker-compose.flink.yml up -d flink-jobmanager flink-taskmanager
echo "==> Flink UI: http://localhost:8081"
