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
ARG BUILD_IMAGE=ghcr.io/getlago/connectors-build:latest
ARG RUNTIME_IMAGE=ghcr.io/getlago/connectors-base:latest

# Must match the upstream image tag this replaces, so component behaviour and
# config schema stay identical.
ARG CONNECT_VERSION=v4.78.0

# CVE bumps applied over whatever connect v4.78.0's go.mod resolves to. These
# are the modules Wiz flagged on the published image; `go get` on an
# already-satisfied version is a no-op, so a stale line here is harmless but
# misleading — drop one once CONNECT_VERSION requires at least it.
# x/net is set ABOVE the v0.55.0 the advisory asks for, and that is
# load-bearing. connect v4.78.0 already resolves x/net to v0.58.0, so
# `go get golang.org/x/net@v0.55.0` is a DOWNGRADE — and downgrading x/net
# drags x/crypto down with it, landing on v0.55.0 and silently undoing the
# crypto bump below. Keep every pin here at or above what the dependency
# graph already selects; a bump must never be a downgrade.
ARG GO_CRYPTO_VERSION=v0.56.0
ARG GO_NET_VERSION=v0.58.0
ARG GO_GRPC_VERSION=v1.83.2

# ---------------------------------------------------------------------------
# Build stage — a tiny module that imports only the components we run.
# ---------------------------------------------------------------------------
FROM ${BUILD_IMAGE} AS build

ARG CONNECT_VERSION
ARG GO_CRYPTO_VERSION
ARG GO_NET_VERSION
ARG GO_GRPC_VERSION

WORKDIR /src

COPY main.go .

# go.mod/go.sum are generated here rather than committed: the module exists
# only to select components, and `go mod tidy` resolving against the pinned
# CONNECT_VERSION is what makes the dependency set reproducible. Promote them
# into the repo if you want the build to run without the module proxy.
# ORDER MATTERS. `go mod tidy` recomputes module selection, and running it
# after the CVE bumps silently undoes them: with tidy last, x/crypto resolved
# back to v0.55.0 even though v0.56.0 was requested — and x/crypto carried 7
# of this image's 14 critical findings. Tidy first, bump second, then verify.
RUN go mod init lago-connectors && \
    go get github.com/redpanda-data/connect/v4@${CONNECT_VERSION} && \
    go mod tidy && \
    go get golang.org/x/crypto@${GO_CRYPTO_VERSION} && \
    go get golang.org/x/net@${GO_NET_VERSION} && \
    go get google.golang.org/grpc@${GO_GRPC_VERSION}

# Fail the build if a bump did not stick, rather than shipping an image that
# looks hardened and is not. `go list` reports the version actually selected
# for the build, which is the only number that matters.
RUN set -eu; \
    for mod in "golang.org/x/crypto=${GO_CRYPTO_VERSION}" "golang.org/x/net=${GO_NET_VERSION}" "google.golang.org/grpc=${GO_GRPC_VERSION}"; do \
      m=${mod%%=*}; want=${mod##*=}; \
      got=$(go list -m -f '{{.Version}}' "$m"); \
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
