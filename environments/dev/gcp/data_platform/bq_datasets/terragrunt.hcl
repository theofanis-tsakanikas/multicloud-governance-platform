# ┌─ SIMULATED SOURCE SYSTEM ─────────────────────────────────────────────┐
# │ Not part of the governance platform. It stands in for an operational │
# │ database owned by an application team, so the federated catalog has  │
# │ a live engine to discover. In production this layer is deleted and   │
# │ the connector points at the team's existing endpoint. See ADR-0014.  │
# └──────────────────────────────────────────────────────────────────────┘

include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  gcp_seed = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.gcp_seed_secret_arn,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  # Datasets = the federated catalog's schema names, from the domain model
  domain = jsondecode(file("${get_terragrunt_dir()}/../../../domains/gcp/marketing_infra.json"))
  fed    = [for c in local.domain.catalogs : c if c.type == "FEDERATED"]
  datasets = flatten([
    for c in local.fed : [for s in lookup(c, "schemas", []) : s.schema_name]
  ])
}

terraform {
  source = "../../../../../infra/gcp/modules/data_platform//bq_datasets"
}

generate "provider_google" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOP
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOP
}

inputs = {
  provider_key = local.gcp_seed.provider_key
  project_id   = local.cfg.gcp_project_id
  location     = local.cfg.gcp_location
  datasets     = local.datasets
}
