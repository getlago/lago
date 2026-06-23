# Lago hardening loop - friendly entrypoints.
# Everything here just calls the scripts in repo-gates/. Run `make help`.
.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help verify verify-strict pins go accounting mcp connectors compose \
        deploy-check smoke harden review gate tools

help: ## Show this help
	@echo "Lago hardening loop - common commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'

verify: ## Run ALL gates (normal mode: missing tools = warning)
	@./repo-gates/verify.sh

verify-strict: ## Run ALL gates in STRICT mode (skips = failures; the real verdict)
	@STRICT=1 ./repo-gates/verify.sh

# Per-gate targets: exit 2 means "passed, but some checks were skipped" -> treat
# as success for make (only a real failure, exit 1, should stop make).
pins: ## Gate: no floating versions (package.json / images / @latest)
	@./repo-gates/check-pins.sh || [ $$? -eq 2 ]

go: ## Gate: Go events-processor (fmt/vet/lint/build/test)
	@./repo-gates/go-gate.sh || [ $$? -eq 2 ]

accounting: ## Gate: outbound accounting contract (exactly-once)
	@./repo-gates/accounting-contract.sh || [ $$? -eq 2 ]

mcp: ## Gate: read-only MCP server (agent tools, GET-only)
	@./repo-gates/mcp-gate.sh || [ $$? -eq 2 ]

connectors: ## Gate: Redpanda Connect connector configs
	@./repo-gates/connectors-gate.sh || [ $$? -eq 2 ]

compose: ## Gate: docker compose / Dockerfile / shell
	@./repo-gates/compose-gate.sh || [ $$? -eq 2 ]

deploy-check: ## Gate: Kamal 2.11.0 + Helm deploy artifacts
	@./repo-gates/deploy-check.sh || [ $$? -eq 2 ]

smoke: ## Live gate: boot the stack and prove the API answers (SMOKE_UP=1 to boot)
	@./repo-gates/smoke.sh || [ $$? -eq 2 ]

harden: ## Inner loop: let Claude fix until the gates pass (bills Anthropic; ROUNDS/MAX_TURNS)
	@./repo-gates/harden.sh

review: ## Fresh-eyes Claude review -> review-findings.json (bills Anthropic)
	@./repo-gates/review.sh

gate: ## Final merge verdict: gates STRICT-green AND no critical/high findings
	@./repo-gates/gate.sh

tools: ## Show which optional gate tools are installed vs missing
	@echo "Optional tools the gates can use (missing => those checks SKIP):"
	@for t in go golangci-lint docker hadolint shellcheck jq kamal helm bundle ruby curl; do \
	  if command -v $$t >/dev/null 2>&1; then printf "  \033[32m[ok]\033[0m   %s\n" "$$t"; \
	  else printf "  \033[33m[miss]\033[0m %s\n" "$$t"; fi; done
