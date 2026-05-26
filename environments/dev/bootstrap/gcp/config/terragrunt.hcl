include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  seed = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.gcp_seed_secret_arn,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "platform" {
  config_path = "../platform"
}

terraform {
  source = "../../../../../infra/bootstrap/modules//shared_config"
}

generate "provider_databricks" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "workspace"
      host          = "${dependency.platform.outputs.gcp_serverless_workspace_url}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  environment                = local.cfg.environment
  serverless_workspace_host  = dependency.platform.outputs.gcp_serverless_workspace_url
  dbx_account_id             = local.cfg.gcp_dbx_account_id
  spn_client_id              = local.seed.client_id
  spn_client_secret          = local.seed.client_secret
  warehouse_prefix           = "gcp-${local.cfg.warehouse_prefix}"
  warehouse_size             = local.cfg.warehouse_size
  max_num_clusters           = local.cfg.max_num_clusters
  auto_stop_mins             = local.cfg.auto_stop_mins
  warehouse_access_groups    = local.cfg.warehouse_access_groups
  warehouse_permission_level = local.cfg.warehouse_permission_level
  metastore_id               = dependency.platform.outputs.gcp_metastore_id
  admin_group_name           = local.cfg.admin_group_name
}
