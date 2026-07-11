include "root" {
  path = find_in_parent_folders()
}

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

      # snowflake_git_repository is still a preview resource; without this the plan fails with
      # an unknown-resource error rather than anything that hints at the cause (ADR-0015).
      preview_features_enabled = ["snowflake_git_repository_resource"]
    }

    # The storage integration is a two-way trust: Snowflake mints an IAM user, and an AWS
    # role must trust it. Both halves are applied here so the trust can never half-exist.
    provider "aws" {
      region = "${local.cfg.aws_region}"
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

  # Snowflake reads the demo notebooks out of the repository rather than having them uploaded.
  github_owner_url = local.cfg.github_owner_url
  github_repo_url  = local.cfg.github_repo_url

  catalogs_json              = jsonencode(local.managed_catalogs)
  external_locations_json    = jsonencode(local.infra.external_locations)
  catalog_grants_json        = jsonencode(local.grants.catalog_grants)
  managed_schema_grants_json = jsonencode(local.managed_schema_grants)
  volume_grants_json         = jsonencode(local.grants.volume_grants)
  ext_loc_grants_json        = jsonencode(local.grants.external_location_grants)
}
