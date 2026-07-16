# syntax=docker/dockerfile:1.25

# --- deps stage: install node_modules only ---------------------------------
FROM node:24.18.0-alpine AS deps

WORKDIR /app

# corepack reads the pinned pnpm version from package.json's `packageManager`
# field — no `pnpm@latest` drift.
RUN apk add --no-cache python3 build-base && corepack enable

# Only copy manifests here so this layer — and the pnpm install below — stay
# cached across any source-only change.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages/configs/package.json        ./packages/configs/
COPY packages/design-system/package.json  ./packages/design-system/

# --ignore-scripts skips `postinstall` (which would try to build workspace
# packages that we haven't copied source for yet — `prebuild` in the build
# stage takes care of that). Replaces the previous `pnpmfile.docker.cjs` hack.
# The BuildKit cache mount on pnpm's content-addressable store means repeat
# installs re-use downloaded tarballs even across `--no-cache` rebuilds, as
# long as the runner persists the mount (e.g. buildx `cache-to`/`cache-from`).
RUN --mount=type=cache,target=/root/.local/share/pnpm/store,sharing=locked \
    pnpm install --frozen-lockfile --ignore-scripts


# --- build stage: compile the app ------------------------------------------
FROM node:24.18.0-alpine AS build

WORKDIR /app
ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN apk add --no-cache python3 build-base && corepack enable

COPY --from=deps /app /app
COPY . .

# Late ARGs — declared here so a change to APP_VERSION only invalidates the
# final `pnpm build` step, never the install above.
# SENTRY_AUTH_TOKEN is intentionally NOT an ARG: it's a credential, and ARG
# values can leak into the final image's history layers and are flagged by
# the Dockerfile linter (SecretsUsedInArgOrEnv). It's mounted as a build
# secret on the RUN below instead.
ARG SENTRY_DSN
ARG SENTRY_ORG
ARG SENTRY_FRONT_PROJECT
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION

# `pnpm build` runs `prebuild` first, which builds `lago-design-system`.
# `--mount=type=secret,id=sentry_auth_token,env=SENTRY_AUTH_TOKEN` exposes
# the secret only as an env var to this single RUN — never written to the
# image filesystem, never persisted in build history. Requires the calling
# workflow to pass `secrets: sentry_auth_token=...` to docker buildx build.
RUN --mount=type=secret,id=sentry_auth_token,env=SENTRY_AUTH_TOKEN \
    pnpm build


# --- runtime stage: nginx serving the built dist ---------------------------
FROM nginx:1.31-alpine AS runtime

WORKDIR /usr/share/nginx/html

# Blanket `apk upgrade` pulls the latest CVE patches for every package in the
# base image. Costs ~5 MB vs hand-curating a package list, but auto-catches
# new CVEs (e.g. a future zlib bump) without anyone remembering to add them.
RUN apk upgrade --no-cache && apk add --no-cache bash

COPY --from=build /app/dist .
COPY ./nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx/gzip.conf /etc/nginx/conf.d/gzip.conf
COPY ./nginx/csp.conf /etc/nginx/conf.d/csp.conf
COPY ./.env.sh ./.env.sh

EXPOSE 80

# `exec` so nginx replaces bash as PID 1 and receives SIGTERM directly.
# (bash would implicitly exec a single trailing command anyway, but being
# explicit removes the reliance on that interpreter optimization.)
ENTRYPOINT ["/bin/bash", "-c", "./.env.sh && exec nginx -g \"daemon off;\""]
