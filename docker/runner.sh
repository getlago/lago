#!/bin/bash

declare -A ENV_VARS=(
    [POSTGRES_PASSWORD]=$(openssl rand -hex 16)
    [SECRET_KEY_BASE]=$(openssl rand -base64 16)
    [LAGO_RSA_PRIVATE_KEY]=$(openssl genrsa 2048 | base64 | tr -d '\n')
    [REDIS_URL]="redis://localhost:6379/0"
    [LAGO_FRONT_URL]="http://localhost"
    [LAGO_API_URL]="http://localhost:3000"
    [API_URL]="http://localhost:3000"
    [APP_ENV]="production"
)

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

# Start Redis, PG and Nginx
service redis-server start >> /dev/null
service postgresql restart >> /dev/null
service nginx restart >> /dev/null

# Prepare Environment
# Defaulting values
for VAR in "${!ENV_VARS[@]}"; do
    if [ -z "${!VAR}" ]; then
        export $VAR=${ENV_VARS[$VAR]}
        echo "$VAR=${ENV_VARS[$VAR]}" >> ${DATA_DIR}/.env
    fi
done

if [ -z "${DATABASE_URL}" ]; then
    export DATABASE_URL=postgresql://lago:$POSTGRES_PASSWORD@localhost:5432/lago
    echo "DATABASE_URL=${DATABASE_URL}" >> ${DATA_DIR}/.env
fi

# Prepare Front Environment
cd ./front
bash -c ./.env.sh
cd ..

export RAILS_ENV=production

# Create DB User
su -c "psql -tc \"SELECT 1 FROM pg_user WHERE usename = 'lago';\" | grep -q 1 || psql -c \"CREATE ROLE lago PASSWORD '${POSTGRES_PASSWORD}' CREATEDB LOGIN;\"" postgres >> ${DATA_DIR}/db.log

# Launch BE Services
cd ./api
bundle exec rake db:create >> ${DATA_DIR}/db.log
bundle exec rake db:migrate >> ${DATA_DIR}/db.log
bundle exec rails signup:seed_organization >> ${DATA_DIR}/db.log
rm -f ./tmp/pids/server.pid
foreman start
