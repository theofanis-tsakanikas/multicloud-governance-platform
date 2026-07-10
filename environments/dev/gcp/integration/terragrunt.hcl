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

dependency "foundation" {
  config_path = "../foundation"
}

dependency "network" {
  config_path = "../network"
}

terraform {
  source = "../../../../infra/gcp/modules//integration"
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
    provider "aws" { region = "${local.cfg.aws_region}" }
  EOF
}

inputs = {
  project_id      = local.cfg.gcp_project_id
  location        = local.cfg.gcp_location
  provider_key    = local.gcp_seed.provider_key
  gcs_bucket_name = dependency.foundation.outputs.gcs_bucket_name
  network_name    = local.cfg.network_name
  subnetwork_name = local.cfg.subnetwork_name

  # Public mode: this layer is a no-op. Private mode also needs the VPN endpoints,
  # which come from the network layer.
  is_private_connection = local.cfg.is_private_connection_gcp
  gcp_vpc_id            = dependency.network.outputs.gcp_vpc_id
  gcp_vpn_gw_id         = dependency.network.outputs.gcp_vpn_gw_id
  gcp_vpn_gw_ips        = dependency.network.outputs.gcp_vpn_gw_ips
  aws_vpn_gw_id         = dependency.network.outputs.aws_vpn_gw_id
  databricks_vpc_id     = dependency.network.outputs.vpc_id
}
