include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # Fetch seed credentials (initial admin credentials, set once manually)
  seed = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.seed_credentials_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

terraform {
  source = "../../../../../infra/bootstrap/modules//aws_foundation"
}

generate "provider_aws" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.cfg.aws_region}"
    }
    provider "databricks" {
      alias         = "mws"
      host          = "${local.cfg.databricks_host}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.initial_client_id
      client_secret = var.initial_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  environment             = local.cfg.environment
  region                  = local.cfg.aws_region
  databricks_host         = local.cfg.databricks_host
  dbx_account_id          = local.cfg.dbx_account_id
  dbx_aws_account_id      = local.cfg.dbx_aws_account_id
  metastore_bucket_name   = local.cfg.metastore_bucket_name
  metastore_iam_role_name = local.cfg.metastore_iam_role_name
  cross_account_role_name = local.cfg.cross_account_role_name
  secret_base_path        = local.cfg.secret_base_path
  secret_recovery_window  = local.cfg.secret_recovery_window
  kms_deletion_window     = local.cfg.kms_deletion_window
  spn_suffix              = local.cfg.spn_suffix
  admin_group_name        = local.cfg.admin_group_name
  metastore_admins        = local.cfg.metastore_admins
  identity_groups         = local.cfg.identity_groups
  initial_client_id       = local.seed.client_id
  initial_client_secret   = local.seed.client_secret
}
