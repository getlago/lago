# DONE.md — the finish line for "production ready"

You can't loop toward "perfect" if nothing defines it. This is the definition.
The repo is production-ready for enterprise billing when **every box is checked
under STRICT mode** (`STRICT=1 ./repo-gates/verify.sh` green) and a fresh-eyes
review surfaces no unresolved critical/high findings.

This list **ratchets**: every time a real bug escapes the gates, add a check here
and a gate for it so it can never escape again.

## Objective gates (must all be green under STRICT)

- [ ] **Pins** — `repo-gates/pins-allow.txt` is empty; no floating versions
      anywhere (`package.json` exact, no `:latest`, no `@latest`).
- [ ] **Go events-processor** — `gofmt` clean, `go vet` clean, `golangci-lint`
      clean, `go build ./...` and `go test ./...` pass **with the CGO Rust lib
      built** (CI, or `GO_TEST_IN_DOCKER=1`).
- [ ] **Connectors** — `connectors/*.yml` pass `redpanda-connect lint`
      (not just YAML parse).
- [ ] **Compose / Docker / shell** — all compose files validate; `hadolint`
      error-level clean; `shellcheck` error-level clean.
- [ ] **Deploy** — Kamal is exactly **2.11.0**; `kamal config` renders;
      `helm lint` and `helm template` succeed.

## Tooling installed so nothing SKIPs

- [ ] `go` + `libexpression_go.so`, `golangci-lint`, `hadolint`, `shellcheck`,
      `kamal` 2.11.0, `helm`, `jq` all present in CI.
- [ ] `STRICT=1 ./repo-gates/verify.sh` is **green** (no SKIPs left).

## Live / runtime (the bug-class the last repo taught us)

- [ ] `make smoke` (or `SMOKE_UP=1 make smoke`) proves the API answers
      `GET /health` → 200, and routing responds at `/api/v1` (not all-404).
- [ ] DB migrations run cleanly (`./scripts/migrate.sh`) before the app serves.

## Deploy artifacts are real, not just valid

- [ ] `config/deploy.yml` has no `<PLACEHOLDER>` left; servers/registry/domain set.
- [ ] `.kamal/secrets` exists locally / in your secret store (never committed).
- [ ] Helm `lago-secrets` Secret documented and created in the target namespace.
- [ ] Every image tag (Kamal accessories + Helm `values.yaml`) is pinned.

## Review & sign-off

- [ ] `make review` run; `review-findings.json` has **0 critical, 0 high** open.
- [ ] `make gate` prints **MERGE-ELIGIBLE**.
- [ ] A human read `git diff` and approved. (Agents do the 80%; you own the merge.)

---

### Ratchet log (add a line every time a bug slips through)

- _2026-… — example: "smoke test added after an all-404 ASGI bug shipped green."_
