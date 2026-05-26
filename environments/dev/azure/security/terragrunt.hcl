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
  source = "../../../../infra/azure/modules//security"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm"  { features {} }
    provider "azuread"  {}
    provider "msgraph"  {}
  EOF
}

inputs = {
  environment         = local.cfg.environment
  location            = local.cfg.azure_location
  databricks_app_name = local.cfg.databricks_app_name
  adls_account_id     = dependency.foundation.outputs.adls_account_id
  role_names          = local.cfg.role_names
  key_vault_id        = dependency.foundation.outputs.key_vault_id
}
