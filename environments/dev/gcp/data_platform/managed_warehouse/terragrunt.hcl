include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  spn = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//managed_warehouse"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      host          = "${dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.gcp_spn_client_id
      client_secret = var.gcp_spn_client_secret
    }
  EOF
}

inputs = {
  gcp_managed_workspace_host = dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url
  gcp_dbx_account_id         = local.cfg.gcp_dbx_account_id
  gcp_spn_client_id          = local.spn.client_id
  gcp_spn_client_secret      = local.spn.client_secret
  managed_warehouse_name     = "${local.cfg.warehouse_prefix}_gcp"
  managed_cluster_size       = local.cfg.warehouse_size
  managed_max_num_clusters   = local.cfg.max_num_clusters
  managed_auto_stop_mins     = local.cfg.auto_stop_mins
  managed_serverless_compute = true
}
