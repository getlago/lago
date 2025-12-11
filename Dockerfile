# Railway-compatible Dockerfile for Lago Payment Module
# This Dockerfile handles submodule cloning and builds the all-in-one image

ARG NODE_VERSION=20
ARG RUBY_VERSION=3.4.7
ARG LAGO_VERSION=v1.37.0

# =============================================================================
# Stage 1: Clone submodules (api and front)
# =============================================================================
FROM alpine:3.20 AS submodules

RUN apk add --no-cache git

WORKDIR /repos

ARG LAGO_VERSION

# Clone the API repository
RUN git clone --depth 1 --branch ${LAGO_VERSION} https://github.com/getlago/lago-api.git api || \
    git clone --depth 1 https://github.com/getlago/lago-api.git api

# Clone the Front repository
RUN git clone --depth 1 --branch ${LAGO_VERSION} https://github.com/getlago/lago-front.git front || \
    git clone --depth 1 https://github.com/getlago/lago-front.git front

# =============================================================================
# Stage 2: Build Frontend
# =============================================================================
FROM node:${NODE_VERSION}-alpine AS front_build

WORKDIR /app

# Copy frontend source from submodules stage
COPY --from=submodules /repos/front .

RUN apk add python3 build-base && \
    corepack enable && corepack prepare pnpm@latest --activate && \
    pnpm install && pnpm build

# =============================================================================
# Stage 3: Build API (Ruby on Rails)
# =============================================================================
FROM ruby:${RUBY_VERSION}-slim AS api_build

ENV BUNDLER_VERSION='2.5.5'
ENV PATH="$PATH:/root/.cargo/bin/"

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && \
    apt-get install nodejs curl build-essential git pkg-config libpq-dev libclang-dev libyaml-dev -y && \
    curl https://sh.rustup.rs -sSf | bash -s -- -y

# Copy API source from submodules stage
COPY --from=submodules /repos/api/Gemfile /app/Gemfile
COPY --from=submodules /repos/api/Gemfile.lock /app/Gemfile.lock

RUN gem install bundler --no-document -v '2.5.5' && \
    gem install foreman && \
    bundle config build.nokogiri --use-system-libraries && \
    bundle install --jobs=3 --retry=3 --without development test

# =============================================================================
# Stage 4: Final Production Image
# =============================================================================
FROM ruby:${RUBY_VERSION}-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update -y && \
    apt-get install curl ca-certificates gnupg lsb-release -y && \
    # PostgreSQL repository
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update && \
    apt-get install nginx xz-utils git libpq-dev postgresql-16 redis-server -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy nginx configuration
COPY ./docker/nginx.conf /etc/nginx/sites-enabled/default

# Copy frontend build
COPY --from=front_build /app/dist /app/front

# Copy Ruby dependencies
COPY --from=api_build /usr/local/bundle/ /usr/local/bundle

# Copy frontend env script
COPY --from=submodules /repos/front/.env.sh ./front/.env.sh

# Copy API source
COPY --from=submodules /repos/api ./api

# Copy configuration files
COPY ./docker/Procfile ./api/Procfile
COPY ./docker/runner.sh ./runner.sh
COPY ./docker/redis.conf /etc/redis/redis.conf

# Make runner script executable
RUN chmod +x ./runner.sh

# Expose ports
EXPOSE 80
EXPOSE 3000

# Data volume for persistence
VOLUME /data

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1

ENTRYPOINT ["./runner.sh"]
