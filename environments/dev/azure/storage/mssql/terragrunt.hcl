# ┌─ SIMULATED SOURCE SYSTEM ─────────────────────────────────────────────┐
# │ Not part of the governance platform. It stands in for an operational │
# │ database owned by an application team, so the federated catalog has  │
# │ a live engine to discover. In production this layer is deleted and   │
# │ the connector points at the team's existing endpoint. See ADR-0014.  │
# └──────────────────────────────────────────────────────────────────────┘

include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  orchestrator_cidr = [
    "${trimspace(run_cmd("--terragrunt-quiet", "bash", "-c", "curl -fsS https://api.ipify.org"))}/32"
  ]
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
    provider "azurerm" {
      features {}
    }
    provider "azuread"  {}
    provider "random"   {}
  EOF
}

inputs = {
  environment          = local.cfg.environment
  location             = local.cfg.azure_location
  region               = local.cfg.aws_region
  resource_group_name  = dependency.foundation.outputs.resource_group_name
  sql_server_name      = local.cfg.sql_server_name
  sql_database_name    = local.cfg.sql_database_name
  sql_admin_user       = local.cfg.sql_admin_user
  sql_password_name    = local.cfg.sql_password_name
  key_vault_id         = dependency.foundation.outputs.key_vault_id
  databricks_aws_cidrs = local.cfg.databricks_vpc_cidr != "" ? [local.cfg.databricks_vpc_cidr] : []
  # The identity applying this layer must be able to reach the server: the very
  # next layer (mssql_schemas) opens a SQL connection to create schemas. In CI
  # that is the GitHub runner; locally it is the laptop. Neither is in the AWS
  # EC2 ranges the firewall otherwise allows, so resolve it at plan time.
  orch_ip               = local.orchestrator_cidr
  is_private_connection = local.cfg.is_private_connection_azure
}
