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

  # ── Domain governance — loaded natively, no Python required ──────────────
  domain_path = "${get_terragrunt_dir()}/../../../domains/aws"
  infra        = jsondecode(file("${local.domain_path}/sales_infra.json"))
  grants       = jsondecode(file("${local.domain_path}/sales_grants.json"))

  managed_catalogs   = [for c in local.infra.catalogs : c if c.type == "MANAGED"]
  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
  federated_names    = toset([for c in local.federated_catalogs : c.catalog_name])

  # Filter schema grants: managed = schemas NOT in federated catalogs
  managed_schema_grants = [
    for g in local.grants.schema_grants : g
    if !contains([for n in local.federated_names : "${n}."], split(".", g.schema)[0] + ".")
  ]
}

dependency "foundation" {
  config_path = "../../foundation"
}

dependency "dbx_creds" {
  config_path = "../dbx_creds"
}

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/aws/modules/data_platform//dbx_governance"
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
    provider "time" {}
  EOF
}

inputs = {
  environment                = local.cfg.environment
  serverless_workspace_host  = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id             = local.cfg.dbx_account_id
  spn_client_id              = local.spn.client_id
  spn_client_secret          = local.spn.client_secret
  bucket_name                = dependency.foundation.outputs.data_bucket_name
  storage_credential_name    = dependency.dbx_creds.outputs.storage_credential_name
  managed_storage_root       = local.infra.managed_storage_root
  deployment_id_aws          = local.cfg.deployment_id_aws
  external_locations_json    = jsonencode(local.infra.external_locations)
  catalogs_json              = jsonencode(local.managed_catalogs)
  ext_loc_grants_json        = jsonencode(local.grants.external_location_grants)
  catalog_grants_json        = jsonencode(local.grants.catalog_grants)
  managed_schema_grants_json = jsonencode(local.managed_schema_grants)
  volume_grants_json         = jsonencode(local.grants.volume_grants)
}
