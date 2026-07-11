include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  gcp_seed = jsondecode(run_cmd("--terragrunt-quiet",
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
  project_id      = local.cfg.gcp_project_id
  location        = local.cfg.gcp_location
  provider_key    = local.gcp_seed.provider_key
  gcp_vpc_cidr    = local.cfg.gcp_vpc_cidr
  gcp_subnet_cidr = local.cfg.gcp_subnet_cidr
  network_name    = local.cfg.network_name
  subnetwork_name = local.cfg.subnetwork_name

  region                = local.cfg.aws_region
  is_private_connection = local.cfg.is_private_connection_gcp

  # GCP's own AWS transit VPC. NOT databricks_vpc_cidr (10.10.0.0/16) — that is Azure's hub, it is
  # live and carrying Azure SQL, and nothing here may touch it.
  transit_vpc_cidr = local.cfg.gcp_transit_vpc_cidr
  transit_subnets  = local.cfg.gcp_transit_subnets
  transit_nat_cidr = local.cfg.gcp_transit_nat_cidr
  ecr_repo_name    = local.cfg.gcp_ecr_repo_name

  # The route that hands private.googleapis.com traffic to Google's private API frontend.
  private_api_vip_cidr = local.cfg.gcp_private_api_vip_cidr
}
