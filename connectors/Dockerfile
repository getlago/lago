# syntax=docker/dockerfile:1.26

# Trimmed, hardened Redpanda Connect build for Lago's ingest connectors.
#
# Replaces `FROM docker.redpanda.com/redpandadata/connect:4.78.0`, which ships
# every Redpanda Connect component. Lago's configs use four, and the unused
# ones brought their own CVEs: of the 14 critical / 30 high findings Wiz
# reported on this image, every single one was a Go module compiled into the
# vendor binary (detectionMethod=LIBRARY, zero OS packages) — including
# amqp091-go (3 crit) and jackc/pgx (2 crit), for connectors nothing here
# references. Swapping only the base image would have fixed none of them.
#
# So this builds the binary from source with just the components main.go
# imports, on the lago-packages Wolfi bases.
#
# LICENSING: the components we link are Apache-2.0. Verified at v4.78.0 on
# the implementing files — internal/impl/aws/input_sqs.go and
# internal/impl/kafka both carry the Apache-2.0 header. The repo is
# dual-licensed (Apache-2.0 + Redpanda Community License) and declares no
# repo-level licence, so re-check headers before adding a component.
ARG BUILD_IMAGE=ghcr.io/getlago/connectors-build:4c7f4748689da0f6ca6f5dcee4068b144966c71e
ARG RUNTIME_IMAGE=ghcr.io/getlago/connectors-base:latest

# Component behaviour and config schema follow this version. Lint the
# configs on every bump (see README).
ARG CONNECT_VERSION=v4.115.1

# Minimum versions for modules Wiz flagged on earlier images. The build
# forces none of them: CONNECT_VERSION already selects at or above each one.
# The check below fails the build if a later CONNECT_VERSION goes below one.
# To force a version again, `go get` it AFTER `go mod tidy`: tidy recomputes
# module selection and undoes an earlier bump.
ARG MIN_MODULE_VERSIONS="golang.org/x/crypto=v0.56.0 golang.org/x/net=v0.58.0 google.golang.org/grpc=v1.83.2 github.com/jackc/pgx/v5=v5.9.2"

# ---------------------------------------------------------------------------
# Build stage — a tiny module that imports only the components we run.
# ---------------------------------------------------------------------------
FROM ${BUILD_IMAGE} AS build

ARG CONNECT_VERSION
ARG MIN_MODULE_VERSIONS

WORKDIR /src

COPY main.go .

# go.mod/go.sum are generated here rather than committed: the module exists
# only to select components, and `go mod tidy` resolving against the pinned
# CONNECT_VERSION is what makes the dependency set reproducible. Promote them
# into the repo if you want the build to run without the module proxy.
RUN go mod init lago-connectors && \
    go get github.com/redpanda-data/connect/v4@${CONNECT_VERSION} && \
    go mod tidy

# Fail the build if a flagged module resolves below its minimum, rather than
# shipping an image that looks hardened and is not. `go list` reports the
# version actually selected for the build, which is the only number that
# matters. A module that is not in the build list is not linked: skip it.
RUN set -eu; \
    for mod in ${MIN_MODULE_VERSIONS}; do \
      m=${mod%%=*}; want=${mod##*=}; \
      if ! got=$(go list -m -f '{{.Version}}' "$m" 2>/dev/null); then \
        echo "ok: $m not in the build list"; continue; \
      fi; \
      if [ "$(printf '%s\n%s\n' "$want" "$got" | sort -V | head -1)" != "$want" ]; then \
        echo "ERROR: $m resolved to $got, below required $want" >&2; exit 1; \
      fi; \
      echo "ok: $m $got (>= $want)"; \
    done

# -trimpath drops local build paths; the ldflags strip debug info. Static by
# construction — CGO_ENABLED=0 comes from the build base — which is why the
# runtime image can ship without libc.
RUN go build -trimpath -ldflags="-s -w" -o /redpanda-connect .

# ---------------------------------------------------------------------------
# Runtime — Wolfi, 3 packages, uid 65532, no shell and no package manager.
# ---------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE}

# Binary stays at / and the configs at the base's work-dir (/app) so the
# existing pod commands keep working unchanged:
#   command: [/redpanda-connect, run, ./sqs.yml]
COPY --from=build /redpanda-connect /redpanda-connect
COPY *.yml ./
