include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals
}

terraform {
  source = "../../../../infra/aws/modules//network"
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
  is_private_connection = local.cfg.is_private_connection
  rds_vpc_cidr          = local.cfg.rds_vpc_cidr
  rds_subnets_config    = local.cfg.rds_subnets_config
  orch_ip               = []
}
