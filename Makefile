SHELL := /bin/bash
.PHONY: help validate fmt bootstrap-aws bootstrap-gcp \
        plan-aws plan-azure plan-gcp apply-aws apply-azure apply-gcp \
        destroy-aws destroy-azure destroy-gcp \
        plan apply destroy clean

ENV_DIR   := environments/dev
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
	@echo "    make fmt             — auto-fix formatting"
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
