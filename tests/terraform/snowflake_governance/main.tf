# Offline validation harness for the Snowflake governance backend.
#
# Mirrors what the Terragrunt leaf does at plan time (read the domain JSON, filter MANAGED
# catalogs, hand the sections to the wrapper as jsonencode'd strings) so the whole module
# tree can be `terraform validate`d with NO Snowflake account and NO credentials —
# `terraform init -backend=false && terraform validate`. Exercised by
# tests/test_snowflake_terraform.py, and never applied.

terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.17.0"
    }
  }
}

provider "snowflake" {
  # No connection is made during `validate`; real credentials come from a TOML profile
  # (or the creds layer) at plan/apply time.
}

locals {
  infra  = jsondecode(file("${path.module}/../../../environments/dev/domains/aws/sales_infra.json"))
  grants = jsondecode(file("${path.module}/../../../environments/dev/domains/aws/sales_grants.json"))

  managed         = [for c in local.infra.catalogs : c if c.type == "MANAGED"]
  federated_names = toset([for c in local.infra.catalogs : c.catalog_name if c.type == "FEDERATED"])
  managed_schema_grants = [
    for g in local.grants.schema_grants : g
    if !contains([for n in local.federated_names : "${n}."], "${split(".", g.schema)[0]}.")
  ]
}

module "snowflake_governance" {
  source = "../../../infra/aws/modules/data_platform/snowflake_governance"

  environment              = "dev"
  domain                   = local.infra.domain
  owner                    = "data_engineers"
  storage_bucket           = "example-data-bucket"
  storage_integration_name = "DEV_STORAGE_INTEGRATION"

  catalogs_json              = jsonencode(local.managed)
  external_locations_json    = jsonencode(local.infra.external_locations)
  catalog_grants_json        = jsonencode(local.grants.catalog_grants)
  managed_schema_grants_json = jsonencode(local.managed_schema_grants)
  volume_grants_json         = jsonencode(local.grants.volume_grants)
  ext_loc_grants_json        = jsonencode(local.grants.external_location_grants)
}
