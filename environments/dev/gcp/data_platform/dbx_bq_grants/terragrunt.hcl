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

  domain_path = "${get_terragrunt_dir()}/../../domains/gcp"
  infra        = jsondecode(file("${local.domain_path}/marketing_infra.json"))
  grants       = jsondecode(file("${local.domain_path}/marketing_grants.json"))

  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
  federated_names    = toset([for c in local.federated_catalogs : c.catalog_name])

  federated_schema_grants = [
    for g in local.grants.schema_grants : g
    if contains(local.federated_names, split(".", g.schema)[0])
  ]
}

dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

dependency "dbx_bq_connector" {
  config_path = "../dbx_bq_connector"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_bq_grants"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "uc_mws"
      host          = "${dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.gcp_spn_client_id
      client_secret = var.gcp_spn_client_secret
    }
  EOF
}

inputs = {
  gcp_serverless_workspace_host = dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url
  gcp_dbx_account_id            = local.cfg.gcp_dbx_account_id
  gcp_spn_client_id             = local.spn.client_id
  gcp_spn_client_secret         = local.spn.client_secret
  federated_catalogs_json       = jsonencode(local.federated_catalogs)
  federated_schema_grants_json  = jsonencode(local.federated_schema_grants)
}
