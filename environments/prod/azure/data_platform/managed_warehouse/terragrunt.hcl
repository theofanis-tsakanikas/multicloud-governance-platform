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

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/azure/modules/data_platform//managed_warehouse"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      # ARM_CLIENT_ID/ARM_TENANT_ID are exported for the azurerm provider, and the
      # databricks provider treats them as an Azure auth method — then finds
      # client_id/client_secret too and refuses: "more than one authorization
      # method configured: azure and oauth". Name the one we mean.
      auth_type     = "oauth-m2m"
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  is_private_connection      = local.cfg.is_private_connection_azure
  managed_workspace_host     = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id             = local.cfg.dbx_account_id
  spn_client_id              = local.spn.client_id
  spn_client_secret          = local.spn.client_secret
  managed_warehouse_name     = "${local.cfg.warehouse_prefix}_azure"
  managed_cluster_size       = local.cfg.warehouse_size
  managed_max_num_clusters   = local.cfg.max_num_clusters
  managed_auto_stop_mins     = local.cfg.auto_stop_mins
  managed_serverless_compute = true
}
