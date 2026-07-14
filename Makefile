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

# conftest: on PATH (CI installs it there) or the gitignored ./.bin vendored copy. Empty if neither.
CONFTEST := $(shell command -v conftest 2>/dev/null || (test -x ./.bin/conftest && echo ./.bin/conftest))

help:
	@echo ""
	@echo "  $(GREEN)Multi-Cloud Governance Platform$(RESET)"
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
	@echo "    make gate-proof       — attack the gate: six violations, all must be refused"
	@echo "    make gate-attack      — narrated, paused walkthrough of the gate refusing (for recording)"
	@echo "    make gate-green       — run the whole offline gate and show every check turn green"
	@echo ""
	@echo "  $(YELLOW)Snowflake — second enforcement backend (engine-agnostic)$(RESET)"
	@echo "    make snowflake-check    — prove UC ≡ Snowflake access-equivalence (offline)"
	@echo "    make snowflake-render    — show the Snowflake grants translated from the contract"
	@echo "    make snowflake-validate  — terraform validate the Snowflake backend (offline)"
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
	@echo "$(GREEN)▶ cross-backend consistency: UC ≡ Snowflake (offline)$(RESET)"
	python3 scripts/snowflake_backend.py --check

test:
	@echo "$(GREEN)▶ ruff$(RESET)"
	ruff check scripts tests
	ruff format --check scripts tests
	@echo "$(GREEN)▶ pytest$(RESET)"
	pytest -q

# ─── Governance copilot ──────────────────────────────────────────────────────

.PHONY: policy-scan policy-sarif gate-proof gate-attack gate-green governance-report genie-space genie-deploy metrics cost-estimate catalog-drift opa demo \
        snowflake-check snowflake-validate snowflake-render

policy-scan:
	@echo "$(GREEN)▶ access-policy analysis (deterministic, CI gate)$(RESET)"
	python3 scripts/policy_analyzer.py --warn-expiring 30

gate-proof:  ## attack the gate and prove it holds — six deliberate violations, all refused
	@echo "$(GREEN)▶ attacking the gate (mutations land in a throwaway copy)$(RESET)"
	python3 scripts/gate_proof.py

gate-attack:  ## narrated, paused walkthrough of the gate REFUSING violations — for a screen recording
	python3 scripts/gate_demo.py

gate-green:  ## run the whole offline gate and show every check turn green — for a screen recording
	python3 scripts/gate_green.py

lint-workflows:  ## assert GitHub can read every workflow file
	python3 scripts/lint_workflows.py

policy-sarif:
	@echo "$(GREEN)▶ writing policy.sarif (GitHub code scanning)$(RESET)"
	python3 scripts/policy_analyzer.py --format sarif --output policy.sarif

governance-report:
	@echo "$(GREEN)▶ regenerating governance report + grounding pack + metrics + cost$(RESET)"
	python3 scripts/governance_report.py
	python3 scripts/genie_space.py
	python3 scripts/governance_metrics.py
	python3 scripts/cost_estimate.py

genie-deploy:  ## provision the Genie governance copilot (needs DATABRICKS_HOST + GENIE_WAREHOUSE_ID)
	python3 scripts/genie_space.py --deploy

genie-space:
	@echo "$(GREEN)▶ regenerating Genie governance-copilot artifacts$(RESET)"
	python3 scripts/genie_space.py

metrics:
	@echo "$(GREEN)▶ governance telemetry$(RESET)"
	python3 scripts/governance_metrics.py --stdout

cost-estimate:
	@echo "$(GREEN)▶ cost + carbon floor$(RESET)"
	python3 scripts/cost_estimate.py

snowflake-check:
	@echo "$(GREEN)▶ cross-backend consistency: UC ≡ Snowflake (offline)$(RESET)"
	python3 scripts/snowflake_backend.py --check

snowflake-render:
	@echo "$(GREEN)▶ Snowflake grants translated from the shared contract$(RESET)"
	python3 scripts/snowflake_backend.py --render

snowflake-validate:
	@echo "$(GREEN)▶ terraform validate the Snowflake backend (offline, no creds)$(RESET)"
	terraform -chdir=tests/terraform/snowflake_governance init -backend=false -input=false
	terraform -chdir=tests/terraform/snowflake_governance validate

catalog-drift:
	@echo "$(GREEN)▶ reconcile declared grants vs live Unity Catalog$(RESET)"
	python3 scripts/catalog_drift.py

opa:
	@if [ -z "$(CONFTEST)" ]; then \
		echo "$(YELLOW)conftest not found (not on PATH, no ./.bin/conftest). Install it — or the offline mirror runs via: pytest tests/test_opa_consistency.py$(RESET)"; \
		exit 0; \
	fi
	@echo "$(GREEN)▶ OPA/Conftest cross-check — clean config must pass$(RESET)"
	$(CONFTEST) test docs/governance/governance_context.json --policy policy/opa
	@echo "$(GREEN)▶ OPA/Conftest cross-check — unsafe fixture must be denied$(RESET)"
	@! $(CONFTEST) test policy/opa/examples/violation_input.json --policy policy/opa >/dev/null 2>&1 \
		&& echo "$(GREEN)✔ rego denied the unsafe fixture as expected$(RESET)" \
		|| (echo "rego did NOT deny the unsafe fixture" && exit 1)

# ─── Offline demo (no cloud, no creds — the whole governance story in ~30s) ────

demo:
	@echo "$(GREEN)═══ 1/6 · validate domain config ═══$(RESET)"
	python3 scripts/validate_domains.py
	@echo "$(GREEN)═══ 2/6 · deterministic access-policy gate + cross-backend equivalence ═══$(RESET)"
	python3 scripts/policy_analyzer.py --warn-expiring 60
	python3 scripts/snowflake_backend.py --check
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

# Bootstrap layers apply IN SEQUENCE (not run-all): foundation creates the SPN
# secret + outputs that platform/config read via run_cmd at parse time. run-all
# evaluates every layer's locals upfront, so it aborts on a fresh environment.
bootstrap-aws:
	@for layer in foundation platform config; do \
		echo "=== bootstrap-aws: apply $$layer ==="; \
		$(TG) apply $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/aws/$$layer || exit 1; \
	done

bootstrap-gcp:
	@for layer in foundation platform config; do \
		echo "=== bootstrap-gcp: apply $$layer ==="; \
		$(TG) apply $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/gcp/$$layer || exit 1; \
	done

# Reverse order. config/platform may have no state (or fail to parse when the SPN
# secret isn't created yet) — tolerate those; foundation holds the real resources
# and must succeed.
bootstrap-aws-destroy:
	@for layer in config platform; do \
		echo "=== bootstrap-aws-destroy: $$layer (tolerated) ==="; \
		$(TG) destroy $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/aws/$$layer || echo "  ($$layer skipped: no state / not bootstrapped)"; \
	done
	$(TG) destroy $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/aws/foundation

bootstrap-gcp-destroy:
	@for layer in config platform; do \
		echo "=== bootstrap-gcp-destroy: $$layer (tolerated) ==="; \
		$(TG) destroy $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/gcp/$$layer || echo "  ($$layer skipped: no state / not bootstrapped)"; \
	done
	$(TG) destroy $(TG_FLAGS) -auto-approve --terragrunt-working-dir $(ENV_DIR)/bootstrap/gcp/foundation

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
