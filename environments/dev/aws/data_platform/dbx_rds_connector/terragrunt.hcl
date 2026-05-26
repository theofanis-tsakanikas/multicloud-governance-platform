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

  rds_secret = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.password_name,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "integration" {
  config_path = "../../integration"
}

dependency "rds" {
  config_path = "../../storage/rds"
}

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/aws/modules/data_platform//dbx_rds_connector"
}

generate "provider_databricks" {
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
  serverless_workspace_host = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id            = local.cfg.dbx_account_id
  spn_client_id             = local.spn.client_id
  spn_client_secret         = local.spn.client_secret
  # Private mode: use custom DNS name (NLB route). Public mode: direct RDS hostname
  rds_hostname              = local.cfg.is_private_connection ? local.cfg.rds_custom_dns_name : dependency.rds.outputs.rds_hostname
  rds_port                  = local.cfg.rds_port
  rds_username              = local.cfg.rds_username
  password                  = local.rds_secret.password
  rds_connection_name       = local.cfg.rds_connection_name
}
