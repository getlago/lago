#!/bin/bash

if [ -f "/data/.env" ]; then
    for LINE in $(cat /data/.env); do export $LINE; done
fi

# Configure data directories
if [ -z "${DATA_DIR}" ]; then
    export DATA_DIR=/data
    mkdir -p ${DATA_DIR}
    mkdir -p ${DATA_DIR}/redis
    chown redis:redis ${DATA_DIR}/redis
    mkdir -p ${DATA_DIR}/postgresql
    touch ${DATA_DIR}/db.log
    touch ${DATA_DIR}/.env
    echo "DATA_DIR=${DATA_DIR}" >> ${DATA_DIR}/.env
fi

# Configure Redis
sed -i "s#DATA_DIR#${DATA_DIR}#g" /etc/redis/redis.conf

# Configure PG
export PGDATA="${DATA_DIR}/postgresql"
export PGPORT=5432

# Prepare FE Environment
bash -c ./front/.env.sh

# Start Redis, PG and Nginx
service redis-server restart >> /dev/null
service postgresql restart >> /dev/null

# Prepare Environment
if [ -z "${POSTGRES_PASSWORD}" ]; then
    export POSTGRES_PASSWORD=$(openssl rand -hex 16)
    echo "POSTGRES_PASSWORD=${POSTGRES_PASSWORD}" >> ${DATA_DIR}/.env
fi

if [ -z "${SECRET_KEY_BASE}" ]; then
    export SECRET_KEY_BASE=$(openssl rand -base64 16)
    echo "SECRET_KEY_BASE=${SECRET_KEY_BASE}" >> ${DATA_DIR}/.env
fi

if [ -z "${LAGO_RSA_PRIVATE_KEY}" ]; then
    export LAGO_RSA_PRIVATE_KEY=$(openssl genrsa 2048 | base64)
    echo "LAGO_RSA_PRIVATE_KEY=${LAGO_RSA_PRIVATE_KEY}" >> ${DATA_DIR}/.env
fi

if [ -z "${DATABASE_URL}" ]; then
    export DATABASE_URL=postgresql://lago:$POSTGRES_PASSWORD@localhost:5432/lago
    echo "DATABASE_URL=${DATABASE_URL}" >> ${DATA_DIR}/.env
fi

if [ -z "${REDIS_URL}" ]; then
    export REDIS_URL="redis://localhost:6379/0"
    echo "REDIS_URL=${REDIS_URL}" >> ${DATA_DIR}/.env
fi

if [ -z "${LAGO_FRONT_URL}" ]; then
    export LAGO_FRONT_URL="http://localhost"
    echo "LAGO_FRONT_URL=${LAGO_FRONT_URL}" >> ${DATA_DIR}/.env
fi

if [ -z "${LAGO_API_URL}" ]; then
    export LAGO_API_URL="http://localhost:3000"
    echo "LAGO_API_URL=${LAGO_API_URL}" >> ${DATA_DIR}/.env
fi

export RAILS_ENV=production

# Create DB User
su -c "psql -tc \"SELECT 1 FROM pg_user WHERE usename = 'lago';\" | grep -q 1 || psql -c \"CREATE ROLE lago PASSWORD '${POSTGRES_PASSWORD}' CREATEDB LOGIN;\"" postgres

# Launch BE Services
cd ./api
bundle exec rake db:create >> ${DATA_DIR}/db.log
bundle exec rake db:migrate >> ${DATA_DIR}/db.log
bundle exec rails signup:seed_organization >> ${DATA_DIR}/db.log
foreman start
