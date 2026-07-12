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

  # The Databricks account SPN, for the account-level provider that creates the NCC rule — the same
  # secrets-at-runtime discipline the AWS and Azure integrations use.
  spn = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
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

# The NCC is in the AWS Databricks account (bootstrap). This is its third private-endpoint rule —
# the RDS and Azure SQL gateways bind to the very same one.
dependency "bootstrap_platform" {
  config_path = "../../bootstrap/aws/platform"
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
    provider "time" {}

    # Account-level Databricks provider — creates the NCC private-endpoint rule.
    provider "databricks" {
      auth_type     = "oauth-m2m"
      alias         = "account"
      host          = "${local.cfg.databricks_host}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
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
  environment           = local.cfg.environment
  region                = local.cfg.aws_region

  gcp_vpc_id     = dependency.network.outputs.gcp_vpc_id
  gcp_vpn_gw_id  = dependency.network.outputs.gcp_vpn_gw_id
  gcp_vpn_gw_ips = dependency.network.outputs.gcp_vpn_gw_ips
  aws_vpn_gw_id  = dependency.network.outputs.aws_vpn_gw_id

  # ── The BigQuery transit gateway ─────────────────────────────────────────────────────────────
  transit_vpc_id     = dependency.network.outputs.vpc_id
  transit_vpc_cidr   = local.cfg.gcp_transit_vpc_cidr
  transit_subnet_ids = dependency.network.outputs.private_subnet_ids
  ecr_repo_name      = dependency.network.outputs.ecr_repo_name

  private_api_vip_ips  = local.cfg.gcp_private_api_vip_ips
  private_api_vip_cidr = local.cfg.gcp_private_api_vip_cidr

  ncc_id                                       = dependency.bootstrap_platform.outputs.ncc_id
  databricks_serverless_privatelink_account_id = local.cfg.dbx_serverless_privatelink_account_id
  spn_client_id                                = local.spn.client_id
  spn_client_secret                            = local.spn.client_secret
}
