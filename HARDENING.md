# Hardening Lago to production — the simple version

This repo runs **metering & billing** for your ERP customers. Before it touches a
real invoice, it has to be *boringly reliable*. This guide sets up a loop that
keeps fixing the code until an honest, dumb machine says "this is ready" — so you
don't have to trust Claude's (or anyone's) word for it.

Read this top-to-bottom once. Then you only ever type a few commands.

---

## 1. The big idea (explain like I'm 5)

Imagine a **vending machine** that only opens if you put in *exactly* the right
coins. It can't be sweet-talked. It doesn't care that you're tired. Right coins →
it opens. Wrong coins → it stays shut.

We build that vending machine for your code. We call it **the gates**
(`./repo-gates/verify.sh`). The gates are a list of pass/fail checks: tests pass,
nothing is broken, every version is pinned, the deploy files are valid.

Then we change everyone's job:

- **Claude's job** is no longer "tell me it's done." It's **"keep fixing until the
  vending machine opens."**
- **The gates' job** is to be the *only* thing allowed to say "done."
- **Your job** is to glance at the result and click merge.

That's the whole trick: a machine that can't be fooled is the judge, and the AI
just keeps feeding it coins until it opens.

```
        ┌─────────────────────────────────────────────┐
        │                                             │
        ▼                                             │
   Claude fixes code  ──►  ./verify.sh (the gates)  ──┤
                                  │                   │
                            green │ red               │ still red? loop again
                                  ▼                   │
                          a 2nd Claude reviews        │
                                  │                   │
                                  ▼                   │
                            YOU click merge ──────────┘  (only humans merge)
```

---

## 2. What the gates check (for *this* repo)

This is the Lago deploy repo. The gates are matched to what actually lives here:

| Gate (`make <name>`) | What it proves |
|---|---|
| `pins`         | No floating versions. Every `package.json` dep, Docker image, and `@latest` install is pinned to an exact version. **(This is the "stop pulling latest" rule you asked for.)** |
| `go`           | The Go **events-processor** is formatted, vets clean, builds, and its unit tests pass. |
| `accounting`   | The outbound **accounting** exactly-once contract holds (`integrations/accounting/`) — given event X, the selected target books entry Y once. Pure Go, runs everywhere. |
| `connectors`   | The Redpanda Connect configs (`connectors/*.yml`) are valid. |
| `compose`      | Every `docker-compose*.yml` parses, Dockerfiles lint, shell scripts have no syntax errors. |
| `deploy-check` | **Kamal is exactly 2.11.0**, `config/deploy.yml` is valid, and the **Helm chart** lints + templates. |
| `smoke`        | (Live) boots the stack and proves the API actually answers `GET /health` — not just that it compiled. |

One command runs them all:

```bash
make verify
```

---

## 3. Two words you need: **normal** vs **STRICT**

A gate can come back three ways: **PASS** (green), **FAIL** (red), or **SKIP**
(yellow — "I couldn't check this because a tool isn't installed here").

- `make verify` → **normal mode.** SKIP is just a warning. Good for everyday work.
- `make verify-strict` → **STRICT mode.** SKIP counts as **FAIL**.

> **Why STRICT exists (important):** a loop is only as honest as its gates. If a
> check is skipped, a "green" run is lying to you. STRICT says *"no skips allowed —
> install the tool and actually run the check."* **CI always runs STRICT**, so the
> real production verdict can never be green-by-accident.

In a fresh sandbox with no extra tools, `make verify` is green and
`make verify-strict` is red — that's correct and expected. You make STRICT green by
installing the tools in section 7 and clearing the debt in section 6.

---

## 4. Do this right now (5 commands)

```bash
# 1. See which optional tools you have (missing ones just SKIP for now)
make tools

# 2. Run the whole judge once. Read the output. This is your baseline.
make verify

# 3. Look at what's only "passing" because of known debt:
make pins          # shows the pre-existing :latest / @latest items as tracked debt

# 4. (Optional, costs Anthropic credits) let Claude fix anything red:
make harden

# 5. When you're happy, get the final merge verdict:
make gate
```

That's it. Day to day you'll mostly type `make verify`.

---

## 5. The loop, step by step (when something is red)

1. **Run the judge:** `make verify`. Read every `[FAIL]`.
2. **Let the fixer loop:** `make harden`.
   This runs `claude -p` with one instruction: *"run the gates, fix the root
   cause, never touch the gates, repeat until green."* It re-runs the gates itself
   between attempts and stops when they pass.
   - Caps so it can't run away or run up a huge bill:
     `ROUNDS=4 MAX_TURNS=30 make harden` (defaults: 3 rounds, 30 turns).
   - It **bills your Anthropic account.** Start small.
3. **Get a second opinion:** `make review`.
   A *different* Claude, with fresh eyes and a hostile attitude, reviews the
   changes and writes `review-findings.json` (critical / high / medium / low).
4. **Final verdict:** `make gate`.
   Merge-eligible only if **STRICT gates are green AND there are no unresolved
   critical/high findings.** It never merges for you.
5. **You read the diff and merge.** `git diff`, then merge. Always your call.

> Golden rule baked into every prompt: **fix the code, never weaken the gate.** If
> Claude ever tries to "fix" a failure by deleting a check, that's the one thing
> the loop forbids.

---

## 6. The version-pinning rule (your "no more latest" ask)

Floating versions are how a build that worked yesterday breaks today: someone,
somewhere pulls a newer `latest` and a waterfall of errors follows. The `pins`
gate forbids it:

- `package.json` → every dependency must be an **exact** version (`1.2.3`, never
  `^1.2.3`, `~1.2`, `*`, or `latest`). *(Your `front` is an empty submodule today,
  so there's no `package.json` in this checkout yet — the rule switches on
  automatically the moment one appears.)*
- Dockerfiles → every `FROM` has a real tag; no `:latest`, no `pnpm@latest`.
- compose files → every `image:` has a pinned tag.

**Pre-existing debt.** When we turned the gate on, the repo already had a few
floats (e.g. `portainer/portainer-ce:latest`, `pnpm@latest`). Rather than block you
on day one, those exact items are listed in
[`repo-gates/pins-allow.txt`](repo-gates/pins-allow.txt) and shown every run as
**tracked debt**. New floats fail immediately; STRICT fails the tracked ones too.

**To clear a debt:** pin it to a real version, then delete its line from
`pins-allow.txt`. Goal: that file becomes empty.

---

## 7. Make STRICT go green (install the real tools)

Each missing tool turns its check from a real PASS into a SKIP. To get the true
production verdict locally, install them (CI already has them):

| Tool | Powers | Install |
|---|---|---|
| Go + the `lago-expression` Rust lib | real `go build`/`go test` for events-processor | see `events-processor/CLAUDE.md` (it needs `libexpression_go.so`); easiest is `GO_TEST_IN_DOCKER=1 make go` |
| `kamal` **2.11.0** | the Kamal half of `deploy-check` | `gem install bundler && bundle install` (uses the pinned `Gemfile`) |
| `helm` | the Helm half of `deploy-check` | https://helm.sh/docs/intro/install/ (pin 3.16.2) |
| `shellcheck` | deeper shell analysis | your package manager |
| `hadolint` | Dockerfile linting | https://github.com/hadolint/hadolint |

> **The events-processor gotcha (don't get fooled):** a plain `go test` *cannot*
> build this service — it links a Rust shared library via CGO. The `go` gate knows
> this and reports **SKIP** (honest), not a fake green. CI builds the Rust lib and
> runs the tests for real. Locally, use `GO_TEST_IN_DOCKER=1 make go`.

---

## 8. Deploying (Kamal 2.11.0 and Helm)

You asked for both. Both ship here, both are checked by `make deploy-check`, and
**both pin every version**.

### Kamal (`config/deploy.yml`, pinned to 2.11.0)

1. `bundle install` (installs Kamal **2.11.0** exactly — see `Gemfile`).
2. Copy `.kamal/secrets.example` → `.kamal/secrets` and fill it in
   (it's gitignored — secrets never get committed).
3. Edit `config/deploy.yml`: replace every `<PLACEHOLDER>` (your servers, registry,
   and billing domain). Comments explain each one.
4. Validate before you ever touch a server: `make deploy-check`.
5. Deploy a **specific** version: `bundle exec kamal deploy --version v1.27.1`.

### Helm (`deploy/helm/lago/`)

```bash
# create the secret Helm expects (never put billing secrets in values.yaml)
kubectl create secret generic lago-secrets \
  --from-literal=DATABASE_URL=... --from-literal=REDIS_URL=... \
  --from-literal=SECRET_KEY_BASE=... # ...and the LAGO_ENCRYPTION_* keys

helm lint  deploy/helm/lago
helm template lago deploy/helm/lago     # eyeball the rendered manifests
helm upgrade --install lago deploy/helm/lago --set domain=billing.yourco.com
```

See [`deploy/helm/lago/README.md`](deploy/helm/lago/README.md) for the full list.

---

## 9. The outer loop (CI — the bouncer at the door)

`.github/workflows/hardening-gates.yml` runs **`STRICT=1 verify.sh`** on every PR.
A pull request can't go green unless the gates do. Turn on branch protection
(require the "hardening-gates" check) and the rule enforces itself — no human has to
remember to run it.

---

## 10. Cheat sheet

```bash
make verify         # run all gates (normal)
make verify-strict  # run all gates (STRICT = the real verdict; CI uses this)
make pins           # just the no-floating-versions gate
make go             # just the Go events-processor gate
make accounting     # just the outbound accounting exactly-once contract
make deploy-check   # just the Kamal 2.11.0 + Helm gate
make smoke          # live: does the API actually answer /health?
make harden         # let Claude fix until green   (bills Anthropic)
make review         # second-opinion review        (bills Anthropic)
make gate           # final merge-eligibility verdict
make tools          # what's installed vs missing
```

**Remember:** the gates are the judge. Claude feeds it coins. You open the door.
