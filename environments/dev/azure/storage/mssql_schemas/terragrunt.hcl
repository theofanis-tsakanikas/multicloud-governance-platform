include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  sql_secret = jsondecode(run_cmd(
    "az", "keyvault", "secret", "show",
    "--vault-name", dependency.foundation.outputs.key_vault_name,
    "--name", local.cfg.sql_password_name,
    "--query", "value",
    "--output", "tsv"
  ))

  domain_path = "${get_terragrunt_dir()}/../../domains/azure"
  infra        = jsondecode(file("${local.domain_path}/supply_infra.json"))

  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
  schemas_to_create  = flatten([
    for cat in local.federated_catalogs : [
      for s in lookup(cat, "schemas", []) : s.schema_name
    ]
  ])
}

dependency "foundation" {
  config_path = "../../foundation"
}

dependency "mssql" {
  config_path = "../mssql"
}

terraform {
  source = "../../../../../infra/azure/modules/storage//mssql_schemas"
}

generate "provider_mssql" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "mssql" {
      hostname = "${dependency.mssql.outputs.sql_server_fqdn}"
      port     = 1433
      sql_auth = {
        username = "${local.cfg.sql_admin_user}"
        password = var.sql_admin_password
      }
    }
  EOF
}

inputs = {
  sql_server_fqdn    = dependency.mssql.outputs.sql_server_fqdn
  sql_database_name  = local.cfg.sql_database_name
  sql_admin_user     = local.cfg.sql_admin_user
  sql_admin_password = trimspace(local.sql_secret)
  mssql_schemas      = local.schemas_to_create
}
