SHELL := /bin/bash
.PHONY: help validate validate-config test fmt bootstrap-aws bootstrap-gcp \
        plan-aws plan-azure plan-gcp apply-aws apply-azure apply-gcp \
        destroy-aws destroy-azure destroy-gcp \
        plan apply destroy clean

# Target environment (dev | prod): `make plan-aws ENV=prod`
ENV       ?= dev
ENV_DIR   := environments/$(ENV)
TG        := terragrunt
TG_FLAGS  := --terragrunt-non-interactive

# Colour helpers
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RESET  := \033[0m

help:
	@echo ""
	@echo "  $(GREEN)Databricks Multicloud Data Platform v2$(RESET)"
	@echo "  ─────────────────────────────────────────"
	@echo "  $(YELLOW)Validation$(RESET)"
	@echo "    make validate        — terraform fmt + terragrunt hclfmt + checkov + tfsec"
	@echo "    make validate-config — offline domain JSON/HCL validation (no cloud creds)"
	@echo "    make test            — ruff + pytest for the config validator"
	@echo "    make fmt             — auto-fix formatting"
	@echo ""
	@echo "  $(YELLOW)Governance copilot (offline, no cloud creds)$(RESET)"
	@echo "    make demo             — run the whole offline governance pipeline end-to-end"
	@echo "    make policy-scan      — deterministic least-privilege/PII access analysis (CI gate)"
	@echo "    make policy-sarif     — write policy.sarif for the GitHub Security tab"
	@echo "    make governance-report — regenerate docs/governance (report + metrics + cost + Genie)"
	@echo "    make genie-space      — regenerate the Genie governance-copilot artifacts"
	@echo "    make metrics          — print governance telemetry (posture/coverage/exceptions)"
	@echo "    make cost-estimate    — regenerate the cost + carbon floor (docs/governance/COST.md)"
	@echo "    make catalog-drift    — reconcile declared grants vs the live UC (deferred)"
	@echo "    make opa              — cross-check the gate with the Rego policy (needs conftest)"
	@echo ""
	@echo "  $(YELLOW)Data pipelines + dashboard (offline, no cloud creds)$(RESET)"
	@echo "    make data            — generate synthetic data → medallion → profile (Level B)"
	@echo "    make dashboard       — render the static governance dashboard (Level A)"
	@echo "    make demo-data       — data pipeline + dashboard, end-to-end"
	@echo ""
	@echo "  $(YELLOW)Bootstrap (run once per account)$(RESET)"
	@echo "    make bootstrap-aws   — apply AWS bootstrap (foundation → platform → config)"
	@echo "    make bootstrap-gcp   — apply GCP bootstrap"
	@echo ""
	@echo "  $(YELLOW)Plan$(RESET)"
	@echo "    make plan-aws        — plan full AWS stack"
	@echo "    make plan-azure      — plan full Azure stack"
	@echo "    make plan-gcp        — plan full GCP stack"
	@echo "    make plan LAYER=aws/network  — plan a single layer"
	@echo ""
	@echo "  $(YELLOW)Apply$(RESET)"
	@echo "    make apply-aws       — apply full AWS stack"
	@echo "    make apply-azure     — apply full Azure stack"
	@echo "    make apply-gcp       — apply full GCP stack"
	@echo "    make apply LAYER=aws/security/iam  — apply a single layer"
	@echo ""
	@echo "  $(YELLOW)Destroy$(RESET)"
	@echo "    make destroy-aws     — destroy full AWS stack (prompts)"
	@echo "    make destroy-azure   — destroy full Azure stack (prompts)"
	@echo "    make destroy-gcp     — destroy full GCP stack (prompts)"
	@echo "    make destroy LAYER=aws/foundation  — destroy a single layer"
	@echo ""
	@echo "  $(YELLOW)Utility$(RESET)"
	@echo "    make clean           — remove .terraform dirs and cache"
	@echo ""

# ─── Validation ──────────────────────────────────────────────────────────────

validate:
	@echo "$(GREEN)▶ terraform fmt check$(RESET)"
	terraform fmt -check -recursive infra/
	@echo "$(GREEN)▶ terragrunt hclfmt check$(RESET)"
	$(TG) hclfmt --check --diff
	@echo "$(GREEN)▶ checkov$(RESET)"
	checkov -d infra/ --framework terraform --compact --quiet
	@echo "$(GREEN)▶ tfsec$(RESET)"
	tfsec infra/
	@echo "$(GREEN)✔ All checks passed$(RESET)"

fmt:
	terraform fmt -recursive infra/
	$(TG) hclfmt

# ─── Domain-config validation (offline — no cloud creds) ───────────────────────

validate-config:
	@echo "$(GREEN)▶ domain config validation (offline)$(RESET)"
	python3 scripts/validate_domains.py
	@echo "$(GREEN)▶ access-policy analysis (offline)$(RESET)"
	python3 scripts/policy_analyzer.py

test:
	@echo "$(GREEN)▶ ruff$(RESET)"
	ruff check scripts tests
	ruff format --check scripts tests
	@echo "$(GREEN)▶ pytest$(RESET)"
	pytest -q

# ─── Governance copilot ──────────────────────────────────────────────────────

.PHONY: policy-scan policy-sarif governance-report genie-space metrics cost-estimate catalog-drift opa demo

policy-scan:
	@echo "$(GREEN)▶ access-policy analysis (deterministic, CI gate)$(RESET)"
	python3 scripts/policy_analyzer.py --warn-expiring 30

policy-sarif:
	@echo "$(GREEN)▶ writing policy.sarif (GitHub code scanning)$(RESET)"
	python3 scripts/policy_analyzer.py --format sarif --output policy.sarif

governance-report:
	@echo "$(GREEN)▶ regenerating governance report + grounding pack + metrics + cost$(RESET)"
	python3 scripts/governance_report.py
	python3 scripts/genie_space.py
	python3 scripts/governance_metrics.py
	python3 scripts/cost_estimate.py

genie-space:
	@echo "$(GREEN)▶ regenerating Genie governance-copilot artifacts$(RESET)"
	python3 scripts/genie_space.py

metrics:
	@echo "$(GREEN)▶ governance telemetry$(RESET)"
	python3 scripts/governance_metrics.py --stdout

cost-estimate:
	@echo "$(GREEN)▶ cost + carbon floor$(RESET)"
	python3 scripts/cost_estimate.py

catalog-drift:
	@echo "$(GREEN)▶ reconcile declared grants vs live Unity Catalog$(RESET)"
	python3 scripts/catalog_drift.py

opa:
	@echo "$(GREEN)▶ OPA/Conftest cross-check — clean config must pass$(RESET)"
	conftest test docs/governance/governance_context.json --policy policy/opa
	@echo "$(GREEN)▶ OPA/Conftest cross-check — unsafe fixture must be denied$(RESET)"
	@! conftest test policy/opa/examples/violation_input.json --policy policy/opa >/dev/null 2>&1 \
		&& echo "$(GREEN)✔ rego denied the unsafe fixture as expected$(RESET)" \
		|| (echo "rego did NOT deny the unsafe fixture" && exit 1)

# ─── Offline demo (no cloud, no creds — the whole governance story in ~30s) ────

demo:
	@echo "$(GREEN)═══ 1/6 · validate domain config ═══$(RESET)"
	python3 scripts/validate_domains.py
	@echo "$(GREEN)═══ 2/6 · deterministic access-policy gate ═══$(RESET)"
	python3 scripts/policy_analyzer.py --warn-expiring 60
	@echo "$(GREEN)═══ 3/6 · governance docs in sync with config ═══$(RESET)"
	python3 scripts/governance_report.py --check
	python3 scripts/genie_space.py --check
	python3 scripts/governance_metrics.py --check
	python3 scripts/cost_estimate.py --check
	@echo "$(GREEN)═══ 4/6 · governance telemetry ═══$(RESET)"
	python3 scripts/governance_metrics.py --stdout
	@echo "$(GREEN)═══ 5/6 · cost + carbon floor ═══$(RESET)"
	python3 scripts/cost_estimate.py --stdout
	@echo "$(GREEN)═══ 6/6 · live-catalog drift (offline summary) ═══$(RESET)"
	python3 scripts/catalog_drift.py
	@echo "$(GREEN)✔ offline governance pipeline complete$(RESET)"

# ─── Data pipelines + dashboard (Level A + B) ─────────────────────────────────

.PHONY: data dashboard demo-data

data:
	@echo "$(GREEN)▶ generate synthetic data (shaped by the governance model)$(RESET)"
	python3 pipelines/generate_data.py
	@echo "$(GREEN)▶ medallion: bronze → silver → gold (sqlite, offline)$(RESET)"
	python3 pipelines/medallion.py
	@echo "$(GREEN)▶ profile: observed PII vs declared classification$(RESET)"
	python3 pipelines/profile_data.py

dashboard:
	@echo "$(GREEN)▶ render static governance dashboard$(RESET)"
	python3 scripts/governance_dashboard.py
	@echo "$(GREEN)✔ open docs/governance/dashboard/index.html$(RESET)"

demo-data: data dashboard
	@echo "$(GREEN)✔ data pipeline + dashboard complete — open docs/governance/dashboard/index.html$(RESET)"

# ─── Bootstrap ───────────────────────────────────────────────────────────────

bootstrap-aws:
	$(TG) run-all apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/bootstrap/aws

bootstrap-gcp:
	$(TG) run-all apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/bootstrap/gcp

bootstrap-aws-destroy:
	$(TG) run-all destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/bootstrap/aws

bootstrap-gcp-destroy:
	$(TG) run-all destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/bootstrap/gcp

# ─── Plan ────────────────────────────────────────────────────────────────────

plan-aws:
	$(TG) run-all plan $(TG_FLAGS) --terragrunt-working-dir $(ENV_DIR)/aws

plan-azure:
	$(TG) run-all plan $(TG_FLAGS) --terragrunt-working-dir $(ENV_DIR)/azure

plan-gcp:
	$(TG) run-all plan $(TG_FLAGS) --terragrunt-working-dir $(ENV_DIR)/gcp

plan:
	@test -n "$(LAYER)" || (echo "Usage: make plan LAYER=aws/network" && exit 1)
	$(TG) plan $(TG_FLAGS) --terragrunt-working-dir $(ENV_DIR)/$(LAYER)

# ─── Apply ───────────────────────────────────────────────────────────────────

apply-aws:
	$(TG) run-all apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/aws

apply-azure:
	$(TG) run-all apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/azure

apply-gcp:
	$(TG) run-all apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/gcp

apply:
	@test -n "$(LAYER)" || (echo "Usage: make apply LAYER=aws/security/iam" && exit 1)
	$(TG) apply $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/$(LAYER)

# ─── Destroy ─────────────────────────────────────────────────────────────────

destroy-aws:
	@read -p "Destroy full AWS stack? Type DESTROY to confirm: " c; \
	[ "$$c" = "DESTROY" ] || (echo "Aborted." && exit 1)
	$(TG) run-all destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/aws

destroy-azure:
	@read -p "Destroy full Azure stack? Type DESTROY to confirm: " c; \
	[ "$$c" = "DESTROY" ] || (echo "Aborted." && exit 1)
	$(TG) run-all destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/azure

destroy-gcp:
	@read -p "Destroy full GCP stack? Type DESTROY to confirm: " c; \
	[ "$$c" = "DESTROY" ] || (echo "Aborted." && exit 1)
	$(TG) run-all destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/gcp

destroy:
	@test -n "$(LAYER)" || (echo "Usage: make destroy LAYER=aws/network" && exit 1)
	@read -p "Destroy $(LAYER)? Type DESTROY to confirm: " c; \
	[ "$$c" = "DESTROY" ] || (echo "Aborted." && exit 1)
	$(TG) destroy $(TG_FLAGS) -auto-approve \
		--terragrunt-working-dir $(ENV_DIR)/$(LAYER)

# ─── Utility ─────────────────────────────────────────────────────────────────

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".terragrunt-cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✔ Cleaned$(RESET)"
