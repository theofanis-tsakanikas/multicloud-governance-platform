include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  gcp_seed = jsondecode(run_cmd(
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

dependency "bootstrap_gcp" {
  config_path = "../../bootstrap/gcp/foundation"
}

terraform {
  source = "../../../../infra/gcp/modules//security"
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
  EOF
}

inputs = {
  project_id      = local.cfg.gcp_project_id
  location        = local.cfg.gcp_location
  provider_key    = local.gcp_seed.provider_key
  gcs_bucket_name = dependency.foundation.outputs.gcs_bucket_name
  dbx_sa_email    = dependency.bootstrap_gcp.outputs.dbx_sa_email
  uc_sa_email     = local.cfg.dbx_system_sa_gcp
}
