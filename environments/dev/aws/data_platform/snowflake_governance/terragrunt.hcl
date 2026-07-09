include "root" {
  path = find_in_parent_folders()
}

# Temporarily skipped: grants reference the Databricks-only federated catalog + the
# deferred external stages. Re-enable after fixing those + the storage integration.
skip = true

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  # ── Domain governance — the SAME JSON the dbx_governance leaf reads ─────────
  domain_path = "${get_terragrunt_dir()}/../../../domains/aws"
  infra       = jsondecode(file("${local.domain_path}/sales_infra.json"))
  grants      = jsondecode(file("${local.domain_path}/sales_grants.json"))

  managed_catalogs = [for c in local.infra.catalogs : c if c.type == "MANAGED"]
  federated_names  = toset([for c in local.infra.catalogs : c.catalog_name if c.type == "FEDERATED"])

  # Managed = schema grants NOT belonging to a federated catalog (mirrors dbx_governance).
  managed_schema_grants = [
    for g in local.grants.schema_grants : g
    if !contains([for n in local.federated_names : "${n}."], "${split(".", g.schema)[0]}.")
  ]
}

terraform {
  source = "../../../../../infra//aws/modules/data_platform/snowflake_governance"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "snowflake" {
      # Authentication comes from a ~/.snowflake/config.toml profile or SNOWFLAKE_* env vars
      # at plan/apply time — no secrets in code (the platform's secrets-at-runtime discipline).
      organization_name = "${local.cfg.snowflake_organization}"
      account_name      = "${local.cfg.snowflake_account}"
    }
  EOF
}

inputs = {
  environment              = local.cfg.environment
  domain                   = local.infra.domain
  owner                    = "data_engineers"
  storage_bucket           = local.cfg.bucket_name
  storage_integration_name = local.cfg.snowflake_storage_integration_name
  warehouse_size           = local.cfg.snowflake_warehouse_size
  credit_quota             = local.cfg.snowflake_credit_quota

  catalogs_json              = jsonencode(local.managed_catalogs)
  external_locations_json    = jsonencode(local.infra.external_locations)
  catalog_grants_json        = jsonencode(local.grants.catalog_grants)
  managed_schema_grants_json = jsonencode(local.managed_schema_grants)
  volume_grants_json         = jsonencode(local.grants.volume_grants)
  ext_loc_grants_json        = jsonencode(local.grants.external_location_grants)
}
