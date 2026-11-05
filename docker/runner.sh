#!/bin/bash
#
# Entrypoint of the all-in-one image, behind tini. Runs as nonroot (uid
# 65532): it starts Postgres, Valkey and nginx as that user, prepares the
# database, then runs the API, the worker and the clock under foreman.
#
# `set -e`: a failed migration or seed stops the container instead of
# booting an API on a half-prepared database.
set -e

echo "Starting Lago..."

declare -A ENV_VARS=(
    [RAILS_ENV]="production"
    [RAILS_LOG_TO_STDOUT]="true"
    [POSTGRES_PASSWORD]=$(openssl rand -hex 16)
    [SECRET_KEY_BASE]=$(openssl rand -base64 16)
    [LAGO_RSA_PRIVATE_KEY]=$(openssl genrsa 2048 2>/dev/null | openssl base64 -A)
    [LAGO_DISABLE_SSL]="true"
    [LAGO_ENCRYPTION_PRIMARY_KEY]=$(openssl rand -hex 16)
    [LAGO_ENCRYPTION_DETERMINISTIC_KEY]=$(openssl rand -hex 16)
    [LAGO_ENCRYPTION_KEY_DERIVATION_SALT]=$(openssl rand -hex 16)
    [REDIS_URL]="redis://localhost:6379/0"
    [LAGO_FRONT_URL]="http://localhost"
    [LAGO_API_URL]="http://localhost:3000"
    [API_URL]="http://localhost:3000"
    [LAGO_PDF_URL]="http://host.docker.internal:3001"
    [APP_ENV]="production"
)

DATA_DIR="${DATA_DIR:-/data}"

# A volume created by the Debian image (before the Wolfi one) is owned by
# root. This image runs as uid 65532 and cannot write to it.
if [ ! -w "${DATA_DIR}" ] || { [ -e "${DATA_DIR}/.env" ] && [ ! -w "${DATA_DIR}/.env" ]; }; then
    echo "ERROR: ${DATA_DIR} is not writable by uid $(id -u)." >&2
    echo "A volume from a Lago image older than the Wolfi one is owned by root. Give it to uid 65532 once:" >&2
    echo "  docker run --rm -u 0 -v <your volume>:/data --entrypoint chown getlago/lago:<tag> -R 65532:65532 /data" >&2
    exit 1
fi

touch "${DATA_DIR}/.env" "${DATA_DIR}/db.log"

if [ -s "${DATA_DIR}/.env" ]; then
    for LINE in $(cat "${DATA_DIR}/.env"); do export "$LINE"; done
fi

if ! grep -q '^DATA_DIR=' "${DATA_DIR}/.env"; then
    echo "DATA_DIR=${DATA_DIR}" >> "${DATA_DIR}/.env"
fi
export DATA_DIR

mkdir -p "${DATA_DIR}/valkey" "${DATA_DIR}/storage"

# Prepare Environment
# Defaulting values
for VAR in "${!ENV_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        export "$VAR=${ENV_VARS[$VAR]}"
        echo "$VAR=${ENV_VARS[$VAR]}" >> "${DATA_DIR}/.env"
    fi
done

if [ -z "${DATABASE_URL}" ]; then
    export DATABASE_URL="postgresql://lago:${POSTGRES_PASSWORD}@localhost:5432/lago"
    echo "DATABASE_URL=${DATABASE_URL}" >> "${DATA_DIR}/.env"
fi

# --- Postgres ---------------------------------------------------------------
# The cluster lives on the volume. The Debian image kept its cluster in the
# container layer, so no older volume holds one.
export PGDATA="${DATA_DIR}/postgresql"
export PGHOST=/tmp
export PGUSER=postgres

# Stop whatever started, on any exit: a failed migration, or foreman ending.
stop_services() {
    nginx -e stderr -s quit 2>/dev/null || true
    valkey-cli shutdown 2>/dev/null || true
    pg_ctl -D "${PGDATA}" -m fast -w stop > /dev/null 2>&1 || true
}
trap stop_services EXIT

if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    # The builtin C.UTF-8 provider does not depend on the glibc collation
    # tables, so a base image update cannot change the sort order of an
    # existing index.
    initdb -D "${PGDATA}" -U postgres -E UTF8 \
        --locale-provider=builtin --builtin-locale=C.UTF-8 \
        --auth-local=trust --auth-host=scram-sha-256 >> "${DATA_DIR}/db.log"
fi

PG_MAJOR=$(pg_config --version | sed -E 's/^PostgreSQL ([0-9]+).*/\1/')
if [ "$(cat "${PGDATA}/PG_VERSION")" != "${PG_MAJOR}" ]; then
    echo "ERROR: ${PGDATA} holds a PostgreSQL $(cat "${PGDATA}/PG_VERSION") cluster; this image runs PostgreSQL ${PG_MAJOR}." >&2
    exit 1
fi

pg_ctl -D "${PGDATA}" -l "${DATA_DIR}/postgresql.log" -w \
    -o "-c listen_addresses=localhost -c unix_socket_directories=/tmp" start > /dev/null

# --- Valkey (Redis protocol) and nginx -----------------------------------------
valkey-server /etc/valkey/valkey.conf --dir "${DATA_DIR}/valkey" \
    --daemonize yes --pidfile /tmp/valkey.pid --logfile "${DATA_DIR}/valkey.log"

# Prepare Front Environment: .env.sh writes env-config.js into its cwd and
# renders the CSP header that nginx.conf includes.
(cd /app/front && CSP_TEMPLATE=/etc/nginx/csp.conf.template CSP_OUTPUT=/tmp/csp.conf ./.env.sh)
nginx -e stderr

# --- Database ---------------------------------------------------------------
# lago is a superuser of this embedded, loopback-only cluster, as in the
# docker-compose setup: lago-api's migrations create the pg_partman extension.
psql -tc "SELECT 1 FROM pg_roles WHERE rolname = 'lago';" | grep -q 1 || \
    psql -q -c "CREATE ROLE lago PASSWORD '${POSTGRES_PASSWORD}' SUPERUSER LOGIN;" >> "${DATA_DIR}/db.log"
unset PGHOST PGUSER

export RAILS_ENV=production

# Launch BE Services
cd /app/api
bundle exec rake db:create >> "${DATA_DIR}/db.log"
bundle exec rake db:migrate >> "${DATA_DIR}/db.log"
bundle exec rake roles:seed_predefined >> "${DATA_DIR}/db.log"
bundle exec rails signup:seed_organization >> "${DATA_DIR}/db.log"
rm -f ./tmp/pids/server.pid

# Only the Ruby processes get jemalloc, as on lago-api-base.
# foreman runs in the background so that this shell gets SIGTERM from tini and
# stops foreman first, then the services (EXIT trap).
# `-t 30`: Sidekiq takes up to 25 s (`timeout` in sidekiq.yml) to push unfinished
# jobs back to Valkey. foreman kills it after 5 s by default, which loses them. The
# container needs a stop timeout above 30 s (`docker run --stop-timeout 40`).
LD_PRELOAD=/usr/lib/libjemalloc.so.2 foreman start -t 30 &
FOREMAN_PID=$!
trap 'kill -TERM "${FOREMAN_PID}" 2>/dev/null' TERM INT
set +e
wait "${FOREMAN_PID}"
STATUS=$?
# A signal interrupts the first wait; wait again for foreman to finish.
if kill -0 "${FOREMAN_PID}" 2>/dev/null; then
    wait "${FOREMAN_PID}"
    STATUS=$?
fi
exit "${STATUS}"
