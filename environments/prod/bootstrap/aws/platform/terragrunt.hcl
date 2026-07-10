include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  spn = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "foundation" {
  config_path = "../foundation"

  # Plan-time only: lets `run-all plan` resolve before foundation is applied.
  # Once foundation is applied its REAL outputs override these; the mocks are
  # locked to plan/validate so they can never reach an apply.
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    metastore_bucket_name  = "mock-metastore-bucket"
    metastore_iam_role_arn = "arn:aws:iam::000000000000:role/mock-metastore-data-access"
    cross_account_role_arn = "arn:aws:iam::000000000000:role/mock-cross-account"
    admin_group_id         = "000000000000000"
    functional_group_ids   = { mock_group = "000000000000000" }
  }
}

terraform {
  source = "../../../../../infra/bootstrap/modules//aws_platform"
}

generate "provider_databricks" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      # Name the auth method explicitly: if ARM_* ever leaks into this job the
      # provider would otherwise see two credentials and refuse to choose.
      auth_type     = "oauth-m2m"
      alias         = "mws"
      host          = "${local.cfg.databricks_host}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  databricks_host              = local.cfg.databricks_host
  dbx_account_id               = local.cfg.dbx_account_id
  spn_client_id                = local.spn.client_id
  spn_client_secret            = local.spn.client_secret
  region                       = local.cfg.aws_region
  environment                  = local.cfg.environment
  metastore_name               = local.cfg.metastore_name
  metastore_bucket_name        = dependency.foundation.outputs.metastore_bucket_name
  metastore_iam_role_arn       = dependency.foundation.outputs.metastore_iam_role_arn
  delta_sharing_token_lifetime = local.cfg.delta_sharing_token_lifetime
  delta_sharing_name           = local.cfg.delta_sharing_name
  workspace_name               = local.cfg.workspace_name
  workspace_pricing_tier       = local.cfg.workspace_pricing_tier
  cross_account_role_arn       = dependency.foundation.outputs.cross_account_role_arn
  admin_group_name             = local.cfg.admin_group_name
  admin_group_id               = dependency.foundation.outputs.admin_group_id
  functional_group_ids         = dependency.foundation.outputs.functional_group_ids
}
