# Root terragrunt.hcl
# Inherited by every child module via find_in_parent_folders()
# Provides: remote state config, provider generation, common inputs

locals {
  # Load the environment config from the nearest config.hcl up the tree
  env_config = read_terragrunt_config(find_in_parent_folders("config.hcl"))
  cfg        = local.env_config.locals

  # Parse the path to determine cloud + layer for state key scoping
  relative_path = path_relative_to_include()
}

# ─── Remote State ────────────────────────────────────────────────────────────
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "dbx-platform-tfstate-${local.cfg.aws_account_id}"
    key            = "${local.relative_path}/terraform.tfstate"
    region         = local.cfg.aws_region
    encrypt        = true
    dynamodb_table = "dbx-platform-tfstate-lock"
  }
}

# ─── Terraform Settings ───────────────────────────────────────────────────────
terraform {
  # Prevent accidental destruction without explicit --terragrunt-no-auto-approve
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
}
