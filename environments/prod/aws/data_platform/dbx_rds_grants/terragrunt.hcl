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

  domain_path = "${get_terragrunt_dir()}/../../domains/aws"
  infra        = jsondecode(file("${local.domain_path}/sales_infra.json"))
  grants       = jsondecode(file("${local.domain_path}/sales_grants.json"))

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

terraform {
  source = "../../../../../infra/aws/modules/data_platform//dbx_rds_grants"
}

generate "provider_databricks" {
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
  EOF
}

inputs = {
  serverless_workspace_host    = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id               = local.cfg.dbx_account_id
  spn_client_id                = local.spn.client_id
  spn_client_secret            = local.spn.client_secret
  federated_catalogs_json      = jsonencode(local.federated_catalogs)
  federated_schema_grants_json = jsonencode(local.federated_schema_grants)
}
