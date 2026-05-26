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

terraform {
  source = "../../../../infra/azure/modules//integration"
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
  environment           = local.cfg.environment
  location              = local.cfg.azure_location
  region                = local.cfg.aws_region
  resource_group_name   = dependency.foundation.outputs.resource_group_name
  is_private_connection = local.cfg.is_private_connection
  vnet_id               = dependency.network.outputs.vnet_id
  endpoint_subnet_id    = dependency.network.outputs.endpoint_subnet_id
}
