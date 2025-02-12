ARG NODE_VERSION=20
ARG RUBY_VERSION=3.3.6

# Front Build
FROM node:$NODE_VERSION-alpine AS front_build

WORKDIR /app

COPY ./front/ .

RUN apk add python3 build-base
RUN yarn && yarn build && npm prune --omit=dev

# API Build
FROM ruby:$RUBY_VERSION-slim AS api_build

ENV BUNDLER_VERSION='2.5.5'
ENV PATH="$PATH:/root/.cargo/bin/"

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && \
    apt-get install nodejs curl build-essential git pkg-config libpq-dev libclang-dev curl -y && \
    curl https://sh.rustup.rs -sSf | bash -s -- -y

COPY ./api/Gemfile /app/Gemfile
COPY ./api/Gemfile.lock /app/Gemfile.lock

RUN gem install bundler --no-document -v '2.5.5' && \
    gem install foreman && \
    bundle config build.nokogiri --use-system-libraries &&\
    bundle install --jobs=3 --retry=3 --without development test

# Final Image
FROM ruby:$RUBY_VERSION-slim

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && \
    apt-get install curl ca-certificates gnupg software-properties-common -y && \
    curl -fsSL https://postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /usr/share/keyrings/postgresql-archive-keyring.gpg > /dev/null && \
    echo deb [arch=amd64,arm64,ppc64e1 signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main | tee /etc/ap && \
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg && \
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg &&\
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list && \
    apt-get update && \
    apt-get install nginx xz-utils git libpq-dev postgresql-15 redis -y && \
    apt-get remove software-properties-common apt-transport-https -y

COPY ./docker/nginx.conf /etc/nginx/sites-enabled/default
COPY ./docker/redis.conf /etc/redis/redis.conf

COPY --from=front_build /app/dist /app/front
COPY --from=api_build /usr/local/bundle/ /usr/local/bundle

COPY ./front/.env.sh ./front/.env.sh
COPY ./api ./api
COPY ./docker/Procfile ./api/Procfile
COPY ./docker/runner.sh ./runner.sh

ENV SEGMENT_WRITE_KEY=$SEGMENT_WRITE_KEY

EXPOSE 80
EXPOSE 3000
VOLUME /data

ENTRYPOINT ["./runner.sh"]
