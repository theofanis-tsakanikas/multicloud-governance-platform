include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # Orchestrator object ID needed for Key Vault access policy
  orch_object_id = run_cmd("az", "ad", "signed-in-user", "show", "--query", "id", "--output", "tsv")
}

terraform {
  source = "../../../../infra/azure/modules//foundation"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" { features {} }
    provider "azuread"  {}
    provider "random"   {}
  EOF
}

inputs = {
  environment           = local.cfg.environment
  location              = local.cfg.azure_location
  prefix_key_vault_name = local.cfg.prefix_key_vault_name
  admin_object_id       = local.cfg.admin_object_id
  orchestrator_object_id = trimspace(local.orch_object_id)
  adls_name             = local.cfg.adls_name
  azure_containers      = local.cfg.azure_containers
}
