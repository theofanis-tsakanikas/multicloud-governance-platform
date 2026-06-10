include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # AWS workspace SPN (for the AWS-side recipient)
  spn = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  gcp_seed = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.gcp_seed_secret_arn,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  # ── Build delta_shares_map from marketing_infra.json shared items ────────
  domain_path = "${get_terragrunt_dir()}/../../domains/gcp"
  infra        = jsondecode(file("${local.domain_path}/marketing_infra.json"))

  # Collect schemas with shared=true (or shared volumes — share entire parent schema)
  shared_schemas = distinct(flatten([
    for cat in local.infra.catalogs : [
      for s in lookup(cat, "schemas", []) : {
        catalog = cat.catalog_name
        schema  = s.schema_name
      }
      if anytrue([for v in lookup(s, "volumes", []) : lookup(v, "shared", false)])
    ]
    if cat.type == "MANAGED"
  ]))

  delta_shares_map = {
    (local.cfg.gcp_delta_sharing_name) = {
      catalog = local.infra.catalogs[0].catalog_name
      schemas = [for s in local.shared_schemas : s.schema]
    }
  }
}

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

dependency "bootstrap_gcp_platform" {
  config_path = "../../../bootstrap/gcp/platform"
}

dependency "dbx_governance" {
  config_path = "../dbx_governance"
}

dependency "aws_governance" {
  config_path = "../../../../aws/data_platform/dbx_governance"
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//dbx_delta_sharing"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      alias         = "gcp_mws"
      host          = "${dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url}"
      account_id    = "${local.cfg.gcp_dbx_account_id}"
      client_id     = var.gcp_spn_client_id
      client_secret = var.gcp_spn_client_secret
    }
    provider "databricks" {
      alias         = "aws_mws"
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOF
}

inputs = {
  gcp_serverless_workspace_host = dependency.bootstrap_gcp_platform.outputs.gcp_serverless_workspace_url
  gcp_dbx_account_id            = local.cfg.gcp_dbx_account_id
  gcp_spn_client_id             = local.spn.client_id
  gcp_spn_client_secret         = local.spn.client_secret
  serverless_workspace_host     = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id                = local.cfg.dbx_account_id
  spn_client_id                 = local.spn.client_id
  spn_client_secret             = local.spn.client_secret
  provider_key                  = local.gcp_seed.provider_key
  delta_shares_map_json         = jsonencode(local.delta_shares_map)
  aws_global_metastore_id       = dependency.bootstrap_platform.outputs.global_metastore_id
  gcp_metastore_id              = dependency.bootstrap_gcp_platform.outputs.gcp_metastore_id
  gcp_provider_name             = dependency.bootstrap_gcp_platform.outputs.gcp_global_metastore_id
}
