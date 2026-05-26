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

terraform {
  source = "../../../../infra/gcp/modules//foundation"
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
    provider "random" {}
  EOF
}

inputs = {
  project_id         = local.cfg.gcp_project_id
  location           = local.cfg.gcp_location
  bucket_prefix_name = local.cfg.gcp_bucket_prefix_name
  service_list       = local.cfg.gcp_service_list
  provider_key       = local.gcp_seed.provider_key
}
