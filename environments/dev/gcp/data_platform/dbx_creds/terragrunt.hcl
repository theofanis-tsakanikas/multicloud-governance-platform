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

  gcp_seed = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.gcp_seed_secret_arn,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

# The GCS storage credential lives in the GCP metastore, so every Databricks
# call here goes to the GCP account and its workspace.
dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

dependency "bootstrap_gcp" {
  config_path = "../../../bootstrap/gcp/foundation"
}

dependency "foundation" {
  config_path = "../../foundation"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_creds"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      host          = "${dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOF
}

inputs = {
  environment                 = local.cfg.environment
  serverless_workspace_host   = dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url
  dbx_account_id              = local.cfg.gcp_dbx_account_id
  spn_client_id               = local.gcp_seed.client_id
  spn_client_secret           = local.gcp_seed.client_secret
  provider_key                = local.gcp_seed.provider_key
  project_id                  = local.cfg.gcp_project_id
  gcs_bucket_name             = dependency.foundation.outputs.gcs_bucket_name
  dbx_sa_email                = dependency.bootstrap_gcp.outputs.dbx_sa_email
  dbx_sa_id                   = dependency.bootstrap_gcp.outputs.dbx_sa_id
  gcp_storage_credential_name = local.cfg.gcp_storage_credential_name
  admin_group_name            = local.cfg.admin_group_name
  wif_pool_id                 = local.cfg.gcp_wif_pool_id
  provider_id                 = local.cfg.gcp_provider_id
}
