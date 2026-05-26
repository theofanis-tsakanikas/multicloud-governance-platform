include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

dependency "foundation" {
  config_path = "../../foundation"
}

terraform {
  source = "../../../../../infra/azure/modules/storage//mssql_database"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm"  { features {} }
    provider "azuread"  {}
    provider "random"   {}
  EOF
}

inputs = {
  environment           = local.cfg.environment
  location              = local.cfg.azure_location
  region                = local.cfg.aws_region
  resource_group_name   = dependency.foundation.outputs.resource_group_name
  sql_server_name       = local.cfg.sql_server_name
  sql_database_name     = local.cfg.sql_database_name
  sql_admin_user        = local.cfg.sql_admin_user
  sql_password_name     = local.cfg.sql_password_name
  key_vault_id          = dependency.foundation.outputs.key_vault_id
  databricks_aws_cidrs  = local.cfg.databricks_vpc_cidr != "" ? [local.cfg.databricks_vpc_cidr] : []
  orch_ip               = []
  is_private_connection = local.cfg.is_private_connection
}
