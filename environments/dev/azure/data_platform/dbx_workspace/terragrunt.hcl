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

dependency "network" {
  config_path = "../../network"
}

dependency "bootstrap_platform" {
  config_path = "../../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/azure/modules/data_platform//dbx_workspace"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "mws"
      host          = "${local.cfg.databricks_host}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  databricks_host        = local.cfg.databricks_host
  dbx_account_id         = local.cfg.dbx_account_id
  spn_client_id          = local.spn.client_id
  spn_client_secret      = local.spn.client_secret
  region                 = local.cfg.aws_region
  dbx_aws_account_id     = local.cfg.dbx_aws_account_id
  managed_workspace_name = local.cfg.workspace_name
  vpc_id                 = dependency.network.outputs.vpc_id
  private_subnet_ids     = dependency.network.outputs.private_subnet_ids
  security_group_id      = dependency.network.outputs.security_group_id
  metastore_id           = dependency.bootstrap_platform.outputs.metastore_id
  is_private_connection  = local.cfg.is_private_connection
}
