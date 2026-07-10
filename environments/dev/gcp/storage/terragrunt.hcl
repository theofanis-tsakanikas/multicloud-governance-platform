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

  domain_path = "${get_terragrunt_dir()}/../../domains/gcp"
  infra       = jsondecode(file("${local.domain_path}/marketing_infra.json"))
  # BigQuery datasets are the FEDERATED catalog's schemas (analytics, web) —
  # not the catalog name. The catalog is the BigQuery *project*.
  datasets = flatten([
    for c in local.infra.catalogs : [for s in lookup(c, "schemas", []) : s.schema_name]
    if c.type == "FEDERATED"
  ])
}

terraform {
  source = "../../../../infra/gcp/modules//storage"
}

generate "provider_gcp" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "google" {
      project     = "${local.cfg.gcp_project_id}"
      region      = "${local.cfg.gcp_location}"
      credentials = var.provider_key
    }
  EOF
}

inputs = {
  project_id   = local.cfg.gcp_project_id
  location     = "EU"
  provider_key = local.gcp_seed.provider_key
  datasets     = local.datasets
}
