include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

terraform {
  source = "../../../../../infra/aws/modules/security//secrets_manager"
}

generate "provider_aws" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.cfg.aws_region}"
    }
    provider "random" {}
  EOF
}

inputs = {
  environment            = local.cfg.environment
  region                 = local.cfg.aws_region
  password_name          = local.cfg.password_name
  rds_username           = local.cfg.rds_username
  db_engine              = local.cfg.db_engine
  rds_port               = local.cfg.rds_port
  db_instance_identifier = local.cfg.db_instance_identifier
}
