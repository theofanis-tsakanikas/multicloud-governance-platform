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

  rds_secret = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.password_name,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "network" {
  config_path = "../../network"
}

terraform {
  source = "../../../../../infra/aws/modules/storage//rds"
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
  environment            = local.cfg.environment
  region                 = local.cfg.aws_region
  db_instance_identifier = local.cfg.db_instance_identifier
  db_name                = local.cfg.db_name
  db_engine              = local.cfg.db_engine
  engine_version         = local.cfg.engine_version
  db_instance_class      = local.cfg.db_instance_class
  allocated_storage      = local.cfg.allocated_storage
  rds_username           = local.cfg.rds_username
  password               = local.rds_secret.password
  db_subnet_group_name   = dependency.network.outputs.db_subnet_group_name
  rds_security_group_id  = dependency.network.outputs.rds_security_group_id
  is_private_connection  = local.cfg.is_private_connection_aws
}
