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

  gcp_seed = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.gcp_seed_secret_arn,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "network" {
  config_path = "../../network"
}

dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_workspace"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "mws"
      host          = "${local.cfg.gcp_databricks_host}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.gcp_spn_client_id
      client_secret = var.gcp_spn_client_secret
    }
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOF
}

inputs = {
  gcp_databricks_host    = local.cfg.gcp_databricks_host
  gcp_dbx_account_id     = local.cfg.gcp_dbx_account_id
  gcp_spn_client_id      = local.spn.client_id
  gcp_spn_client_secret  = local.spn.client_secret
  provider_key           = local.gcp_seed.provider_key
  region                 = local.cfg.aws_region
  dbx_aws_account_id     = local.cfg.dbx_aws_account_id
  managed_workspace_name = local.cfg.gcp_workspace_name
  vpc_id                 = dependency.network.outputs.vpc_id
  private_subnet_ids     = dependency.network.outputs.private_subnet_ids
  security_group_id      = dependency.network.outputs.security_group_id
  metastore_id           = dependency.bootstrap_gcp_platform.outputs.gcp_metastore_id
  is_private_connection  = local.cfg.is_private_connection
}
