include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

dependency "foundation" {
  config_path = "../../foundation"
}

dependency "secrets_manager" {
  config_path = "../secrets_manager"
}

terraform {
  source = "../../../../../infra/aws/modules/security//iam"
}

generate "provider_aws" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.cfg.aws_region}"
    }
  EOF
}

inputs = {
  environment           = local.cfg.environment
  region                = local.cfg.aws_region
  aws_account_id        = local.cfg.aws_account_id
  dbx_aws_account_id    = local.cfg.dbx_aws_account_id
  iam_role_name         = local.cfg.iam_role_name
  data_bucket_arn       = dependency.foundation.outputs.data_bucket_arn
  rds_secret_arn        = dependency.secrets_manager.outputs.rds_secret_arn
  is_private_connection = local.cfg.is_private_connection
}
