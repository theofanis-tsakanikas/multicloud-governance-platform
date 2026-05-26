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

terraform {
  source = "../../../../../infra/bootstrap/modules//gcp_foundation"
}

generate "provider_gcp" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
    provider "databricks" {
      alias         = "mws"
      host          = "${local.cfg.gcp_databricks_host}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.initial_client_id
      client_secret = var.initial_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  project_id            = local.cfg.gcp_project_id
  project_number        = local.cfg.gcp_project_number
  location              = local.cfg.gcp_location
  environment           = local.cfg.environment
  gcp_databricks_host   = local.cfg.gcp_databricks_host
  gcp_dbx_account_id    = local.cfg.gcp_dbx_account_id
  metastore_bucket_name = local.cfg.gcp_metastore_bucket
  dbx_system_sa         = local.cfg.dbx_system_sa_gcp
  dbx_sa_name           = local.cfg.dbx_sa_name
  terraform_sa_account  = local.cfg.terraform_sa_account
  spn_suffix            = local.cfg.spn_suffix
  admin_group_name      = local.cfg.admin_group_name
  metastore_admins      = local.cfg.metastore_admins
  identity_groups       = local.cfg.identity_groups
  service_list          = local.cfg.gcp_service_list
  dbx_sa_secret_id      = local.cfg.gcp_sa_secret_id
  provider_key          = local.seed.provider_key
  initial_client_id     = local.seed.client_id
  initial_client_secret = local.seed.client_secret
}
