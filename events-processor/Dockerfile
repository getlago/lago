# syntax=docker/dockerfile:1.26

# Hardened Wolfi/apko-based events-processor image. Replaces the
# rust:1.85 / golang:1.25 / debian:13-slim chain with the lago-packages
# bases: no apt, no shell in the runtime layer, nonroot by default.
# See getlago/lago-packages for the base image definitions.
#
# TAG PIN: both ARGs below default to an immutable
# `:<lago-packages-commit-sha>`. The daily rebuild of lago-packages
# keeps `:latest` within ~24h of upstream Wolfi; repin here to pick
# that up, so a base bump is a reviewable diff rather than a silent
# change under a floating tag.
ARG BUILD_IMAGE=ghcr.io/getlago/events-processor-build:4c2a516c79a6fb9e26b3bb20a139852a88e45889
ARG RUNTIME_IMAGE=ghcr.io/getlago/events-processor-base:4c2a516c79a6fb9e26b3bb20a139852a88e45889

# lago-expression builds libexpression_go.so, the cdylib that the
# expression-go cgo binding links against (`#cgo LDFLAGS:
# -lexpression_go`). Pinned to the commit behind tag v0.2.0 rather than
# the tag: `git checkout v0.2.0` trusts a ref that can be repointed,
# and the sha is what the build actually resolved to anyway.
ARG LAGO_EXPRESSION_REF=a22ab022ae6f2ebd287244e670626cac98f449f1

# ---------------------------------------------------------------------------
# Rust stage — libexpression_go.so.
# ---------------------------------------------------------------------------
FROM ${BUILD_IMAGE} AS rust-build

ARG LAGO_EXPRESSION_REF

WORKDIR /lago-expression

# Fetch just the pinned commit instead of cloning every branch and tag.
# `--depth 1` on an explicit sha needs uploadpack.allowReachableSHA1InWant,
# which GitHub enables, so this stays a single-commit fetch.
RUN git init -q . && \
    git remote add origin https://github.com/getlago/lago-expression.git && \
    git fetch -q --depth 1 origin "${LAGO_EXPRESSION_REF}" && \
    git checkout -q FETCH_HEAD && \
    cargo build --release --package expression-go

# ---------------------------------------------------------------------------
# Go stage — the event_processors binary. CGO is required: the binary
# links against libexpression_go.so, so this cannot be a static build.
# ---------------------------------------------------------------------------
FROM ${BUILD_IMAGE} AS go-build

WORKDIR /app

# The .so has to be on the linker path before `go build`, not just at
# runtime — expression-go resolves -lexpression_go at link time.
COPY --from=rust-build /lago-expression/target/release/libexpression_go.so /usr/lib/libexpression_go.so

COPY . /app/

RUN go mod download && go mod verify && \
    CGO_ENABLED=1 go build -o event_processors .

# ---------------------------------------------------------------------------
# Runtime stage — hardened Wolfi. events-processor-base carries glibc and
# libgcc (both needed by the cgo binary and the Rust cdylib), plus
# ca-certificates-bundle and tzdata. Nothing else: no shell, no package
# manager.
# ---------------------------------------------------------------------------
FROM ${RUNTIME_IMAGE}

LABEL org.opencontainers.image.source="https://github.com/getlago/lago"
LABEL org.opencontainers.image.description="Hardened Wolfi-based events-processor image for Lago"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

COPY --from=rust-build /lago-expression/target/release/libexpression_go.so /usr/lib/libexpression_go.so
COPY --from=go-build /app/event_processors /app/event_processors

# The base already sets work-dir, run-as and this entrypoint. Restating
# them keeps the image self-sufficient: a base rebuild that drops one
# fails this build loudly instead of silently shipping a root container
# or an image with no entrypoint.
WORKDIR /app
USER 65532
ENTRYPOINT ["/app/event_processors"]
