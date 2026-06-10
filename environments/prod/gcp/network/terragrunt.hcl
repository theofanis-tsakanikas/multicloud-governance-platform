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
  source = "../../../../infra/gcp/modules//network"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
    provider "aws" { region = "${local.cfg.aws_region}" }
  EOF
}

inputs = {
  project_id       = local.cfg.gcp_project_id
  location         = local.cfg.gcp_location
  provider_key     = local.gcp_seed.provider_key
  gcp_vpc_cidr     = local.cfg.gcp_vpc_cidr
  gcp_subnet_cidr  = local.cfg.gcp_subnet_cidr
  network_name     = local.cfg.network_name
  subnetwork_name  = local.cfg.subnetwork_name
}
