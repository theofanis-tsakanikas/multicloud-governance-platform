include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

dependency "foundation" {
  config_path = "../foundation"
}

terraform {
  source = "../../../../infra/azure/modules//network"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws"      { region = "${local.cfg.aws_region}" }
    provider "azurerm"  { features {} }
    provider "azuread"  {}
  EOF
}

inputs = {
  environment            = local.cfg.environment
  region                 = local.cfg.aws_region
  location               = local.cfg.azure_location
  resource_group_name    = dependency.foundation.outputs.resource_group_name
  vnet_name              = local.cfg.vnet_name
  azure_vnet_cidr        = local.cfg.azure_vnet_cidr
  data_subnet_prefix     = local.cfg.data_subnet_prefix
  endpoint_subnet_prefix = local.cfg.endpoint_subnet_prefix
  gateway_subnet_prefix  = local.cfg.gateway_subnet_prefix
  databricks_vpc_cidr    = local.cfg.databricks_vpc_cidr
  databricks_subnets     = local.cfg.databricks_subnets
  key_vault_id           = dependency.foundation.outputs.key_vault_id
  is_private_connection  = local.cfg.is_private_connection
}
