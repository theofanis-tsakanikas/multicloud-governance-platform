include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
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
}
