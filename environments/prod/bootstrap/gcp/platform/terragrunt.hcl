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

dependency "foundation" {
  config_path = "../foundation"
}

terraform {
  source = "../../../../../infra/bootstrap/modules//gcp_platform"
}

generate "provider_gcp" {
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
    provider "time" {}
  EOF
}

inputs = {
  gcp_databricks_host          = local.cfg.gcp_databricks_host
  gcp_dbx_account_id           = local.cfg.gcp_dbx_account_id
  project_id                   = local.cfg.gcp_project_id
  location                     = local.cfg.gcp_location
  environment                  = local.cfg.environment
  gcp_metastore_name           = local.cfg.gcp_metastore_name
  metastore_bucket_name        = dependency.foundation.outputs.metastore_bucket_name
  dbx_sa_email                 = dependency.foundation.outputs.dbx_sa_email
  dbx_sa_id                    = dependency.foundation.outputs.dbx_sa_id
  delta_sharing_token_lifetime = local.cfg.delta_sharing_token_lifetime
  gcp_delta_sharing_name       = local.cfg.gcp_delta_sharing_name
  workspace_name               = local.cfg.gcp_workspace_name
  workspace_pricing_tier       = local.cfg.workspace_pricing_tier
  admin_group_name             = local.cfg.admin_group_name
  admin_group_id               = dependency.foundation.outputs.admin_group_id
  functional_group_ids         = dependency.foundation.outputs.functional_group_ids
  gcp_spn_client_id            = local.seed.client_id
  gcp_spn_client_secret        = local.seed.client_secret
  provider_key                 = local.seed.provider_key
}
