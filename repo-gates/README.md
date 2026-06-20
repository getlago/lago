# repo-gates/ — the honest judge

These scripts are the **gates**: deterministic pass/fail checks that decide whether
the repo is production-ready. Nothing else gets to say "done." Start with the
[`../HARDENING.md`](../HARDENING.md) guide; this is the per-file reference.

## Exit-code convention (every gate)

| code | meaning |
|---|---|
| `0` | all checks passed |
| `1` | a real failure (broken code/config) |
| `2` | nothing failed, but a check was SKIPPED (a tool/env was missing) |

`STRICT=1` turns every SKIP into a FAIL. CI runs STRICT so a green can't be faked.

## Files

| Script | Role |
|---|---|
| `lib.sh` | Shared helpers (colors, PASS/FAIL/SKIP, `finish`). Sourced, sets no shell flags. |
| `verify.sh` | **The judge.** Runs every gate, prints one verdict. `GATES="go pins"` to subset. |
| `check-pins.sh` | No floating versions (`package.json`, Dockerfiles, compose, shell). |
| `pins-allow.txt` | Tracked pre-existing pin debt. Drive it to empty. |
| `go-gate.sh` | Go events-processor: fmt/vet/lint/build/test (CGO-aware; honest SKIP). |
| `accounting-contract.sh` | Outbound accounting exactly-once contract (`integrations/accounting/`, pure Go). |
| `connectors-gate.sh` | Redpanda Connect configs: structure + YAML + optional lint. |
| `compose-gate.sh` | `docker compose config`, hadolint, shellcheck/`bash -n`. |
| `deploy-check.sh` | Kamal **2.11.0** + Helm chart validation. |
| `smoke.sh` | Live: boots/probes the stack, asserts the API answers `/health`. |
| `harden.sh` | **Inner loop.** `claude -p` fixes until `verify.sh` is green. Bills Anthropic. |
| `review.sh` | Fresh-eyes adversarial review → `review-findings.json`. Bills Anthropic. |
| `gate.sh` | **Final verdict.** STRICT-green AND no critical/high findings = merge-eligible. |

## Common commands

```bash
./repo-gates/verify.sh                 # everything, normal mode
STRICT=1 ./repo-gates/verify.sh        # the real production verdict
GATES="pins deploy" ./repo-gates/verify.sh   # only some gates
GO_TEST_IN_DOCKER=1 ./repo-gates/go-gate.sh  # real Go tests in a container
ROUNDS=4 MAX_TURNS=30 ./repo-gates/harden.sh # bounded fixer loop
```

## The one rule

**Never weaken a gate to make it pass.** If a check is red, the code is wrong, not
the check. Fix the root cause. (This rule is also in `../CLAUDE.md`, and it's in the
prompt `harden.sh` gives Claude.)
