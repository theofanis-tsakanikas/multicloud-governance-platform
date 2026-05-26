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

  domain_path        = "${get_terragrunt_dir()}/../../domains/azure"
  infra              = jsondecode(file("${local.domain_path}/supply_infra.json"))
  grants             = jsondecode(file("${local.domain_path}/supply_grants.json"))
  federated_catalogs = [for c in local.infra.catalogs : c if c.type == "FEDERATED"]
}

dependency "bootstrap_platform" {
  config_path = "../../../../bootstrap/aws/platform"
}

dependency "dbx_governance" {
  config_path = "../dbx_governance"
}

terraform {
  source = "../../../../../infra/azure/modules/data_platform//uc_federation"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "databricks" {
      host          = "${dependency.bootstrap_platform.outputs.serverless_workspace_url}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
  EOF
}

inputs = {
  managed_workspace_host = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id         = local.cfg.dbx_account_id
  spn_client_id          = local.spn.client_id
  spn_client_secret      = local.spn.client_secret
  managed_workspace_id   = dependency.bootstrap_platform.outputs.serverless_workspace_id
  catalogs_json          = jsonencode(local.federated_catalogs)
  catalog_grants_json    = jsonencode(local.grants.catalog_grants)
  binding_type           = "READ_WRITE"
}
