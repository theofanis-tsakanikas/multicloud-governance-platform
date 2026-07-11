include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # The Databricks account SPN, for the account-level provider that creates the NCC rule — the
  # same secrets-at-runtime discipline the AWS integration uses.
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

# Private mode wires the SQL server behind a private endpoint, so it must exist
# first. The dir-ordered apply already runs storage before integration.
dependency "mssql" {
  config_path = "../storage/mssql"
}

# The NCC lives in the AWS Databricks account (created at bootstrap). The transit gateway's
# private-endpoint rule binds to it — the same NCC the AWS RDS rule uses.
dependency "bootstrap_platform" {
  config_path = "../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../infra/azure/modules//integration"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws"      { region = "${local.cfg.aws_region}" }
    provider "azurerm" {
      features {}
    }
    provider "azuread"  {}
    provider "time" {}

    # Account-level Databricks provider — creates the NCC private-endpoint rule. Auth method is
    # named explicitly so a stray ARM_* credential in this job cannot make the provider refuse to
    # choose (the same guard the AWS integration uses).
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
  environment           = local.cfg.environment
  location              = local.cfg.azure_location
  region                = local.cfg.aws_region
  resource_group_name   = dependency.foundation.outputs.resource_group_name
  is_private_connection = local.cfg.is_private_connection_azure
  vnet_id               = dependency.network.outputs.vnet_id
  endpoint_subnet_id    = dependency.network.outputs.endpoint_subnet_id

  # Consumed only in private mode; null/ignored in public mode, where this layer
  # creates nothing at all.
  sql_server_name     = dependency.mssql.outputs.sql_server_name
  sql_server_id       = dependency.mssql.outputs.sql_server_id
  sql_server_fqdn     = dependency.mssql.outputs.sql_server_fqdn
  vpc_id              = dependency.network.outputs.vpc_id
  aws_vpn_gw_id       = dependency.network.outputs.aws_vpn_gw_id
  azure_vpn_public_ip = dependency.network.outputs.azure_vpn_public_ip
  azure_vpn_gw_id     = dependency.network.outputs.azure_vpn_gw_id
  azure_vnet_cidr     = local.cfg.azure_vnet_cidr
  databricks_vpc_cidr = local.cfg.databricks_vpc_cidr

  # ── Transit-hub: the AWS gateway + the NCC rule ─────────────────────────────────────────────
  subnet_ids        = dependency.network.outputs.private_subnet_ids
  security_group_id = dependency.network.outputs.security_group_id
  ecr_repo_name     = dependency.network.outputs.ecr_repo_name

  ncc_id                                       = dependency.bootstrap_platform.outputs.ncc_id
  dbx_account_id                               = local.cfg.dbx_account_id
  databricks_serverless_privatelink_account_id = local.cfg.dbx_serverless_privatelink_account_id
  databricks_host                              = local.cfg.databricks_host
  spn_client_id                                = local.spn.client_id
  spn_client_secret                            = local.spn.client_secret
}
