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
}

dependency "iam" {
  config_path = "../../security/iam"
}

dependency "bootstrap_platform" {
  config_path = "../../../bootstrap/aws/platform"
}

terraform {
  source = "../../../../../infra/aws/modules/data_platform//aws_storage_credentials"
}

generate "provider_databricks" {
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
  EOF
}

inputs = {
  environment               = local.cfg.environment
  serverless_workspace_host = dependency.bootstrap_platform.outputs.serverless_workspace_url
  dbx_account_id            = local.cfg.dbx_account_id
  spn_client_id             = local.spn.client_id
  spn_client_secret         = local.spn.client_secret
  iam_role_arn              = dependency.iam.outputs.iam_role_arn
  deployment_id_aws         = local.cfg.deployment_id_aws
}
