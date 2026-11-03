# syntax=docker/dockerfile:1.26

# Hardened Wolfi/apko-based all-in-one Lago image (getlago/lago). Replaces the
# node:24-alpine / ruby:4.0-slim chain and its Debian runtime, which ran every
# process as root and pulled Postgres, Redis and the Docker CLI from apt.
#
# Builds on the lago-packages bases: the lago-api and lago-front build bases,
# and lago-allinone-base for the runtime (Ruby, Postgres 18 + pg_partman,
# Valkey, nginx, nonroot uid 65532). See getlago/lago-packages for the base
# image definitions. The bases are public, so this file builds without
# registry credentials.
#
# BASE PIN: `:<YYYYMMDD>-r<run>@sha256:<index digest>`, an immutable
# lago-packages publish. Docker builds from the digest, so a build is
# reproducible. Renovate (getlago/lago-packages renovate/lago-bases) moves tag
# and digest together when a newer base is published.
ARG API_BUILD_IMAGE=ghcr.io/getlago/lago-api-build:20261103-r1325@sha256:3cdff00432d17ad249e6c287acc59f640536d6b20679d57c3e9aecb709cf1c77
ARG FRONT_BUILD_IMAGE=ghcr.io/getlago/lago-front-build:20261103-r1327@sha256:0e406e30e754d4769ca5181e5fb291fb0b89a6af19c5850405c58b662891f473
# TODO before merge: pin to the first publish of getlago/lago-packages#54.
ARG RUNTIME_IMAGE=ghcr.io/getlago/lago-allinone-base:latest

# ---------------------------------------------------------------------------
# Front build — the static bundle that nginx serves.
# ---------------------------------------------------------------------------
FROM ${FRONT_BUILD_IMAGE} AS front_build

WORKDIR /app

# Same limit as the lago-front Dockerfile: the default heap is too small for
# `pnpm build` on the arm64 runner.
ENV NODE_OPTIONS="--max-old-space-size=4096"

COPY ./front/ .

RUN pnpm install --frozen-lockfile && pnpm build

# ---------------------------------------------------------------------------
# API build — the gem bundle, with native extensions.
# ---------------------------------------------------------------------------
FROM ${API_BUILD_IMAGE} AS api_build

ARG BUNDLER_VERSION=4.0.16

WORKDIR /app

ENV BUNDLE_WITHOUT="development test"
ENV BUNDLE_PATH=/usr/local/bundle
ENV GEM_HOME=/usr/local/bundle
ENV PATH=/usr/local/bundle/bin:${PATH}

COPY ./api/Gemfile ./api/Gemfile.lock ./

RUN gem install bundler --no-document -v "${BUNDLER_VERSION}" && \
  gem install foreman --no-document && \
  bundle config set --local build.nokogiri --use-system-libraries && \
  bundle install --jobs=3 --retry=3

# ---------------------------------------------------------------------------
# Runtime — hardened Wolfi, nonroot. No apt, no Docker CLI.
# ---------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/getlago/lago"
LABEL org.opencontainers.image.description="Hardened Wolfi-based all-in-one Lago image"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

ARG SEGMENT_WRITE_KEY
ENV SEGMENT_WRITE_KEY=${SEGMENT_WRITE_KEY}

ENV BUNDLE_WITHOUT="development test"
ENV BUNDLE_PATH=/usr/local/bundle
ENV GEM_HOME=/usr/local/bundle
ENV PATH=/usr/local/bundle/bin:${PATH}

WORKDIR /app

# Code and config stay root-owned, so the processes cannot rewrite them.
# nonroot owns only what it writes: the front's env-config.js (written by
# .env.sh into ./front), and the API's tmp/ (pids, bootsnap cache) and log/.
COPY --from=api_build /usr/local/bundle /usr/local/bundle
COPY --from=front_build --chown=nonroot:nonroot /app/dist /app/front
COPY ./front/.env.sh /app/front/.env.sh
COPY ./front/nginx/csp.conf.template /etc/nginx/csp.conf.template
COPY ./docker/nginx.conf /etc/nginx/nginx.conf
COPY ./docker/valkey.conf /etc/valkey/valkey.conf
COPY ./api /app/api
COPY ./docker/Procfile /app/api/Procfile
COPY ./docker/runner.sh /app/runner.sh

# Active Storage's local service writes to api/storage (invoice PDFs, CSV
# exports). Point it at the volume, so the files outlive the container.
# runner.sh creates the target. A `COPY --chown` into an existing directory
# leaves that directory root-owned, hence the chown here.
USER 0
RUN chown -R nonroot:nonroot /app/api/tmp /app/api/log && \
  rm -rf /app/api/storage && ln -s /data/storage /app/api/storage

EXPOSE 80
EXPOSE 3000
VOLUME /data

# The base already runs as nonroot. Restating it keeps the image
# self-sufficient: a base rebuild that drops it fails loudly instead of
# shipping a root container.
USER 65532

# tini is PID 1: it forwards SIGTERM to runner.sh, which then stops the
# services in order (Postgres last, with a fast shutdown).
ENTRYPOINT ["/usr/bin/tini", "--", "/app/runner.sh"]
