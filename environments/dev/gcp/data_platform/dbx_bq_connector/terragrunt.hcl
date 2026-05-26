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

  # BQ SA key fetched from GCP Secret Manager (requires gcloud ADC before apply)
  gcp_bq_key = run_cmd(
    "gcloud", "secrets", "versions", "access", "latest",
    "--secret", local.cfg.gcp_sa_secret_id,
    "--project", local.cfg.gcp_project_id
  )

  domain_path        = "${get_terragrunt_dir()}/../../domains/gcp"
  infra              = jsondecode(file("${local.domain_path}/marketing_infra.json"))
  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
}

dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

dependency "bootstrap_gcp_foundation" {
  config_path = "../../../bootstrap/gcp/foundation"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_bq_connector"
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
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOF
}

inputs = {
  gcp_serverless_workspace_host = dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url
  gcp_dbx_account_id            = local.cfg.gcp_dbx_account_id
  gcp_spn_client_id             = local.spn.client_id
  gcp_spn_client_secret         = local.spn.client_secret
  provider_key                  = local.gcp_seed.provider_key
  connection_name               = local.federated_catalogs[0].connection_name
  project_id                    = local.cfg.gcp_project_id
  cred_sa_email                 = dependency.bootstrap_gcp_foundation.outputs.dbx_sa_email
  bq_key                        = local.gcp_bq_key
  admin_group_name              = local.cfg.admin_group_name
}
