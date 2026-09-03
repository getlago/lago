#!/usr/bin/env bash
# Builds the MSF application uber-JAR.
#
# This machine has no JDK or Maven, so the build runs in a container. The
# resulting artifact is byte-identical to what `mvn package` would produce on
# a workstation, which is what makes it the same thing you upload to S3.
#
#   ./scripts/build.sh              # build + run the parity tests
#   ./scripts/build.sh -DskipTests  # fast rebuild
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> building lago-flink-usage.jar (Flink 2.3.0 / Java 17)"
docker compose -f docker-compose.flink.yml run --rm \
  flink-builder mvn -B clean package "$@"

JAR=app/target/lago-flink-usage.jar
if [[ ! -f "$JAR" ]]; then
  echo "!! build produced no $JAR" >&2
  exit 1
fi
SIZE_MB=$(( $(stat -c%s "$JAR") / 1024 / 1024 ))
echo "==> $JAR (${SIZE_MB} MB)"
# MSF rejects application JARs over 512 MB.
if (( SIZE_MB > 512 )); then
  echo "!! JAR exceeds the 512 MB Managed Service for Apache Flink limit" >&2
  exit 1
fi
