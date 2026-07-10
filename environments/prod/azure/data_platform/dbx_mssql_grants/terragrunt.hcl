include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  spn = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  domain_path = "${get_terragrunt_dir()}/../../../domains/azure"
  infra       = jsondecode(file("${local.domain_path}/supply_infra.json"))
  grants      = jsondecode(file("${local.domain_path}/supply_grants.json"))

  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
  federated_names    = toset([for c in local.federated_catalogs : c.catalog_name])

  federated_schema_grants = [
    for g in local.grants.schema_grants : g
    if contains(local.federated_names, split(".", g.schema)[0])
  ]
}

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

dependency "dbx_mssql_connector" {
  config_path = "../dbx_mssql_connector"
}

# The SQL warehouse that warms the foreign catalog before grants apply.
dependency "bootstrap_config" {
  config_path = "../../../bootstrap/aws/config"
}

# Ordering-only: these layers expose no outputs, so they cannot be a
# `dependency` block (Terragrunt requires outputs there). They must still
# apply first — the federated catalog and the remote schemas must exist
# before Databricks can resolve them when applying these grants.
dependencies {
  paths = ["../dbx_governance", "../../storage/mssql_schemas"]
}

terraform {
  source = "../../../../../infra//azure/modules/data_platform/dbx_mssql_grants"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      # ARM_CLIENT_ID/ARM_TENANT_ID are exported for the azurerm provider, and the
      # databricks provider treats them as an Azure auth method — then finds
      # client_id/client_secret too and refuses: "more than one authorization
      # method configured: azure and oauth". Name the one we mean.
      auth_type     = "oauth-m2m"
      alias         = "uc_mws"
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  dbx_workspace_host           = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id               = local.cfg.dbx_account_id
  spn_client_id                = local.spn.client_id
  spn_client_secret            = local.spn.client_secret
  federated_catalogs_json      = jsonencode(local.federated_catalogs)
  federated_schema_grants_json = jsonencode(local.federated_schema_grants)
  warehouse_id                 = dependency.bootstrap_config.outputs.warehouse_id
}
