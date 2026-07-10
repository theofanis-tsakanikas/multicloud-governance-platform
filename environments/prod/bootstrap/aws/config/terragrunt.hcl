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

dependency "platform" {
  config_path = "../platform"

  # Plan-time only (see note in ../platform); locked to plan/validate.
  mock_outputs_allowed_terraform_commands = ["plan", "validate"]
  mock_outputs = {
    serverless_workspace_url = "https://mock-workspace.cloud.databricks.com"
    metastore_id             = "00000000-0000-0000-0000-000000000000"
  }
}

terraform {
  source = "../../../../../infra/bootstrap/modules//shared_config"
}

generate "provider_databricks" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      # Name the auth method explicitly: if ARM_* ever leaks into this job the
      # provider would otherwise see two credentials and refuse to choose.
      auth_type     = "oauth-m2m"
      host          = "${dependency.platform.outputs.serverless_workspace_url}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  environment                = local.cfg.environment
  serverless_workspace_host  = dependency.platform.outputs.serverless_workspace_url
  dbx_account_id             = local.cfg.dbx_account_id
  spn_client_id              = local.spn.client_id
  spn_client_secret          = local.spn.client_secret
  warehouse_prefix           = local.cfg.warehouse_prefix
  warehouse_size             = local.cfg.warehouse_size
  max_num_clusters           = local.cfg.max_num_clusters
  auto_stop_mins             = local.cfg.auto_stop_mins
  warehouse_access_groups    = local.cfg.warehouse_access_groups
  warehouse_permission_level = local.cfg.warehouse_permission_level
  metastore_id               = dependency.platform.outputs.metastore_id
  admin_group_name           = local.cfg.admin_group_name
}
