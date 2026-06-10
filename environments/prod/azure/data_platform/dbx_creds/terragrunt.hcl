include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  spn = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "foundation" {
  config_path = "../../foundation"
}

dependency "security" {
  config_path = "../../security"
}

dependency "bootstrap_platform" {
  config_path = "../../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/azure/modules/data_platform//azure_storage_credentials"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "uc_mws"
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "azurerm" { features {} }
  EOF
}

inputs = {
  environment               = local.cfg.environment
  serverless_workspace_host = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id            = local.cfg.dbx_account_id
  spn_client_id             = local.spn.client_id
  spn_client_secret         = local.spn.client_secret
  azure_storage_credential_name = local.cfg.azure_storage_credential_name
  adls_account_id           = dependency.foundation.outputs.adls_account_id
  az_spn_client_id          = dependency.security.outputs.az_spn_client_id
  az_spn_client_secret      = dependency.security.outputs.az_spn_client_secret
  deployment_id_azure        = local.cfg.deployment_id_azure
}
