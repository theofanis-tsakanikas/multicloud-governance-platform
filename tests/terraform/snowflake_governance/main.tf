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
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "snowflake" {
  # No connection is made during `validate`; real credentials come from a TOML profile
  # (or the creds layer) at plan/apply time.
}

provider "aws" {
  # The wrapper owns the AWS half of the Snowflake storage integration (the IAM role
  # Snowflake assumes). No API call is made during `validate`.
  region                      = "eu-central-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  access_key                  = "mock"
  secret_key                  = "mock"
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

  # Required by the module (the git-backed notebook repository). Mock https URLs — nothing is
  # fetched during `validate`; github_repo_is_public defaults false, so the GIT REPOSITORY object is
  # gated off. These were missing, which made `terraform init` fail on a required-argument error
  # that the test then laundered into a green skip.
  github_owner_url = "https://github.com/example-org"
  github_repo_url  = "https://github.com/example-org/example-repo"

  catalogs_json              = jsonencode(local.managed)
  external_locations_json    = jsonencode(local.infra.external_locations)
  catalog_grants_json        = jsonencode(local.grants.catalog_grants)
  managed_schema_grants_json = jsonencode(local.managed_schema_grants)
  volume_grants_json         = jsonencode(local.grants.volume_grants)
  ext_loc_grants_json        = jsonencode(local.grants.external_location_grants)
}
