#!/bin/bash
# =============================================================================
# Lago Runner Script for Railway
# =============================================================================
# Optimized version of runner.sh for Railway deployment
# - No Docker-in-Docker (PDF service should be separate)
# - Uses Railway-provided PostgreSQL and Redis when available
# - Supports both embedded and external database modes
# =============================================================================

set -e

echo "=============================================="
echo "  Starting Lago on Railway..."
echo "=============================================="

# -----------------------------------------------------------------------------
# Environment Variables with Defaults
# -----------------------------------------------------------------------------
declare -A ENV_VARS=(
    [RAILS_ENV]="production"
    [RAILS_LOG_TO_STDOUT]="true"
    [LAGO_DISABLE_SSL]="true"
    [APP_ENV]="production"
)

# Load saved environment if exists
if [ -f "/data/.env" ]; then
    echo "Loading saved environment from /data/.env"
    set -a
    source /data/.env
    set +a
fi

# -----------------------------------------------------------------------------
# Data Directory Setup
# -----------------------------------------------------------------------------
export DATA_DIR=${DATA_DIR:-/data}
mkdir -p ${DATA_DIR}
mkdir -p ${DATA_DIR}/storage
touch ${DATA_DIR}/.env

# -----------------------------------------------------------------------------
# Security Keys Auto-Generation (if not provided)
# -----------------------------------------------------------------------------
if [ -z "${SECRET_KEY_BASE}" ]; then
    export SECRET_KEY_BASE=$(openssl rand -hex 64)
    echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> ${DATA_DIR}/.env
    echo "Generated SECRET_KEY_BASE"
fi

if [ -z "${LAGO_RSA_PRIVATE_KEY}" ]; then
    export LAGO_RSA_PRIVATE_KEY=$(openssl genrsa 2048 2>/dev/null | base64 -w 0)
    echo "LAGO_RSA_PRIVATE_KEY=${LAGO_RSA_PRIVATE_KEY}" >> ${DATA_DIR}/.env
    echo "Generated LAGO_RSA_PRIVATE_KEY"
fi

if [ -z "${LAGO_ENCRYPTION_PRIMARY_KEY}" ]; then
    export LAGO_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 32)
    echo "LAGO_ENCRYPTION_PRIMARY_KEY=${LAGO_ENCRYPTION_PRIMARY_KEY}" >> ${DATA_DIR}/.env
    echo "Generated LAGO_ENCRYPTION_PRIMARY_KEY"
fi

if [ -z "${LAGO_ENCRYPTION_DETERMINISTIC_KEY}" ]; then
    export LAGO_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 32)
    echo "LAGO_ENCRYPTION_DETERMINISTIC_KEY=${LAGO_ENCRYPTION_DETERMINISTIC_KEY}" >> ${DATA_DIR}/.env
    echo "Generated LAGO_ENCRYPTION_DETERMINISTIC_KEY"
fi

if [ -z "${LAGO_ENCRYPTION_KEY_DERIVATION_SALT}" ]; then
    export LAGO_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
    echo "LAGO_ENCRYPTION_KEY_DERIVATION_SALT=${LAGO_ENCRYPTION_KEY_DERIVATION_SALT}" >> ${DATA_DIR}/.env
    echo "Generated LAGO_ENCRYPTION_KEY_DERIVATION_SALT"
fi

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------
USE_EMBEDDED_DB=${USE_EMBEDDED_DB:-false}

if [ "${USE_EMBEDDED_DB}" = "true" ]; then
    echo "Using embedded PostgreSQL..."

    # Generate password if not set
    if [ -z "${POSTGRES_PASSWORD}" ]; then
        export POSTGRES_PASSWORD=$(openssl rand -hex 16)
        echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" >> ${DATA_DIR}/.env
    fi

    # Configure PostgreSQL
    export PGDATA="${DATA_DIR}/postgresql"
    export PGPORT=${PGPORT:-5432}

    # Initialize PostgreSQL if needed
    if [ ! -d "${PGDATA}" ]; then
        echo "Initializing PostgreSQL..."
        mkdir -p ${PGDATA}
        chown postgres:postgres ${PGDATA}
        su -c "initdb -D ${PGDATA}" postgres
    fi

    # Start PostgreSQL
    echo "Starting PostgreSQL..."
    su -c "pg_ctl -D ${PGDATA} -l ${DATA_DIR}/postgresql.log start" postgres
    sleep 3

    # Create user and database
    su -c "psql -tc \"SELECT 1 FROM pg_user WHERE usename = 'lago';\" | grep -q 1 || psql -c \"CREATE ROLE lago PASSWORD '${POSTGRES_PASSWORD}' CREATEDB LOGIN;\"" postgres

    # Set DATABASE_URL
    if [ -z "${DATABASE_URL}" ]; then
        export DATABASE_URL="postgresql://lago:${POSTGRES_PASSWORD}@localhost:${PGPORT}/lago"
        echo "DATABASE_URL=${DATABASE_URL}" >> ${DATA_DIR}/.env
    fi
else
    echo "Using external PostgreSQL from DATABASE_URL"
    if [ -z "${DATABASE_URL}" ]; then
        echo "ERROR: DATABASE_URL is required when USE_EMBEDDED_DB=false"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Redis Configuration
# -----------------------------------------------------------------------------
USE_EMBEDDED_REDIS=${USE_EMBEDDED_REDIS:-false}

if [ "${USE_EMBEDDED_REDIS}" = "true" ]; then
    echo "Using embedded Redis..."

    # Configure Redis directories
    mkdir -p ${DATA_DIR}/redis
    chown redis:redis ${DATA_DIR}/redis 2>/dev/null || true

    # Update Redis config
    if [ -f /etc/redis/redis.conf ]; then
        sed -i "s#DATA_DIR#${DATA_DIR}#g" /etc/redis/redis.conf
    fi

    # Start Redis
    echo "Starting Redis..."
    redis-server --daemonize yes --dir ${DATA_DIR}/redis
    sleep 2

    # Set REDIS_URL
    if [ -z "${REDIS_URL}" ]; then
        export REDIS_URL="redis://localhost:6379"
        echo "REDIS_URL=${REDIS_URL}" >> ${DATA_DIR}/.env
    fi
else
    echo "Using external Redis from REDIS_URL"
    if [ -z "${REDIS_URL}" ]; then
        echo "ERROR: REDIS_URL is required when USE_EMBEDDED_REDIS=false"
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# URL Configuration
# -----------------------------------------------------------------------------
# Railway provides RAILWAY_PUBLIC_DOMAIN for the public URL
if [ -n "${RAILWAY_PUBLIC_DOMAIN}" ]; then
    export LAGO_API_URL=${LAGO_API_URL:-"https://${RAILWAY_PUBLIC_DOMAIN}"}
    export LAGO_FRONT_URL=${LAGO_FRONT_URL:-"https://${RAILWAY_PUBLIC_DOMAIN}"}
    export API_URL=${API_URL:-"https://${RAILWAY_PUBLIC_DOMAIN}"}
else
    export LAGO_API_URL=${LAGO_API_URL:-"http://localhost:3000"}
    export LAGO_FRONT_URL=${LAGO_FRONT_URL:-"http://localhost"}
    export API_URL=${API_URL:-"http://localhost:3000"}
fi

# PDF Service (external on Railway)
export LAGO_PDF_URL=${LAGO_PDF_URL:-""}
if [ -z "${LAGO_PDF_URL}" ]; then
    echo "WARNING: LAGO_PDF_URL not set. PDF generation will be disabled."
    export LAGO_DISABLE_PDF_GENERATION=true
fi

# -----------------------------------------------------------------------------
# Apply Default Environment Variables
# -----------------------------------------------------------------------------
for VAR in "${!ENV_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        export $VAR=${ENV_VARS[$VAR]}
    fi
done

# -----------------------------------------------------------------------------
# Start Nginx (Frontend)
# -----------------------------------------------------------------------------
echo "Starting Nginx..."
service nginx start || nginx

# Prepare Frontend Environment
if [ -d "./front" ] && [ -f "./front/.env.sh" ]; then
    echo "Configuring frontend environment..."
    cd ./front
    bash ./.env.sh
    cd ..
fi

# -----------------------------------------------------------------------------
# Database Migration
# -----------------------------------------------------------------------------
echo "Running database migrations..."
cd ./api
bundle exec rake db:create 2>/dev/null || true
bundle exec rake db:migrate

# Auto-create organization if configured
if [ "${LAGO_CREATE_ORG}" = "true" ]; then
    echo "Creating organization..."
    bundle exec rails signup:seed_organization || true
fi

# -----------------------------------------------------------------------------
# Start Application Services
# -----------------------------------------------------------------------------
echo "Starting Lago services..."
rm -f ./tmp/pids/server.pid

# Use foreman to manage processes
echo "=============================================="
echo "  Lago is starting!"
echo "  Frontend: ${LAGO_FRONT_URL}"
echo "  API: ${LAGO_API_URL}"
echo "=============================================="

exec foreman start
