# CLAUDE.md — rules for working in this repo

This is the **Lago metering & billing** deploy repo. It bills enterprise ERP
customers, so correctness, data-integrity, and reproducibility beat speed and
cleverness. Read this before changing anything.

## The one rule that matters

**The gates are the judge, not you.** "Done" means `STRICT=1 ./repo-gates/verify.sh`
exits green — never your own assessment. When something is red, fix the **root
cause**. Re-run the gates. Repeat until green.

## Never do this

- **Never edit, weaken, skip, or delete anything in `repo-gates/`** to make a check
  pass. The check is right; the code is wrong. Fix the code.
- **Never introduce a floating version.** No `^`/`~`/`*`/`latest` in `package.json`,
  no `:latest` images, no `pnpm@latest`. Pin to an exact, known-good version. If you
  add a dependency, pin it. (The `pins` gate enforces this.)
- **Never bump Kamal off 2.11.0.** It's pinned in `Gemfile` and `.kamal/version`,
  and `deploy-check` asserts it.
- **Never put secrets in git.** Secrets go in `.kamal/secrets` (gitignored) or a
  Kubernetes Secret — never in `config/deploy.yml`, `values.yaml`, or code.
- **Never fake a green.** If a gate SKIPs because a tool is missing, leave it as a
  SKIP. Do not stub it out.

## How to work

1. `./repo-gates/verify.sh` — read every `[FAIL]`.
2. Fix the smallest change that addresses the root cause.
3. Re-run. When green, stop.
4. Keep diffs minimal and focused on what the gates demand.

## Repo map (what's real here)

- `events-processor/` — Go service. **CGO**: it links a Rust lib
  (`libexpression_go.so`); a bare `go test` won't build. Use
  `GO_TEST_IN_DOCKER=1` or run in CI. See `events-processor/CLAUDE.md`.
- `connectors/` — Redpanda Connect / Benthos pipeline configs (YAML).
- `deploy/`, `docker/`, `docker-compose*.yml`, `traefik/` — deployment plumbing.
- `config/deploy.yml`, `.kamal/` — Kamal 2.11.0 deploy.
- `deploy/helm/lago/` — Helm chart.
- `api/`, `front/` — **empty git submodules** (upstream Rails API + React front).
  Don't assume they're checked out.

## The deploy facts that bite

- API health endpoint: `GET /health` on port `3000` (returns 200).
- Workers are Sidekiq (`./scripts/start.*.worker.sh`); `clock` is a singleton.
- Pin every accessory image (postgres:15-alpine, redis:7-alpine, gotenberg 8.15).

See `HARDENING.md` for the full loop and `repo-gates/README.md` for each gate.
