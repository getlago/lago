#!/usr/bin/env bash
# Submits the application JAR to the local cluster.
#
# On MSF the equivalent is: upload the same JAR to S3, then StartApplication.
# The JAR does not change between the two; only the property source does.
set -euo pipefail
cd "$(dirname "$0")/.."

JAR_IN_CONTAINER=/opt/lago/app/target/lago-flink-usage.jar
if [[ ! -f app/target/lago-flink-usage.jar ]]; then
  echo "!! no JAR — run ./scripts/build.sh first" >&2
  exit 1
fi

docker exec lago_flink_jobmanager flink run -d "$JAR_IN_CONTAINER" "$@"
echo "==> submitted; watch http://localhost:8081"
