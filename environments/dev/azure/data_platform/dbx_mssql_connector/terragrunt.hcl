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

  sql_secret = run_cmd(
    "az", "keyvault", "secret", "show",
    "--vault-name", dependency.foundation.outputs.key_vault_name,
    "--name", local.cfg.sql_password_name,
    "--query", "value",
    "--output", "tsv"
  )

  domain_path        = "${get_terragrunt_dir()}/../../domains/azure"
  infra              = jsondecode(file("${local.domain_path}/supply_infra.json"))
  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
}

dependency "foundation" {
  config_path = "../../foundation"
}

dependency "mssql" {
  config_path = "../../storage/mssql"
}

dependency "bootstrap_platform" {
  config_path = "../../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/azure/modules/data_platform//dbx_mssql_connector"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  dbx_workspace_host = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id     = local.cfg.dbx_account_id
  spn_client_id      = local.spn.client_id
  spn_client_secret  = local.spn.client_secret
  sql_server_host    = dependency.mssql.outputs.sql_server_fqdn
  sql_admin_user     = local.cfg.sql_admin_user
  sql_admin_password = trimspace(local.sql_secret)
  sql_password_name  = local.cfg.sql_password_name
  connection_name    = local.federated_catalogs[0].connection_name
  sql_database_name  = local.cfg.sql_database_name
}
