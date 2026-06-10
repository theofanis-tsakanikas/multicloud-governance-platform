include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

terraform {
  source = "../../../../infra/aws/modules//foundation"
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
  bucket_name           = local.cfg.bucket_name
  ecr_repo_name         = local.cfg.ecr_repo_name
  is_private_connection = local.cfg.is_private_connection
}
