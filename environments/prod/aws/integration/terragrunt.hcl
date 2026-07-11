include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  spn = jsondecode(run_cmd("--terragrunt-quiet",
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.spn_secret_id,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))
}

dependency "network" {
  config_path = "../network"
}

dependency "iam" {
  config_path = "../security/iam"
}

dependency "secrets_manager" {
  config_path = "../security/secrets_manager"
}

dependency "bootstrap_platform" {
  config_path = "../../bootstrap/aws/platform"
}

# The RDS Proxy attaches to the instance by identifier, and the identifier is a literal in
# config.hcl — so nothing made Terragrunt wait for the instance to exist. The CI workflow only
# survived it by looping the layers in a fixed order; `make apply-aws` runs `run-all` over the
# whole tree and is free to reach integration first, where the proxy target then fails with
# DBInstanceNotFound. Declare the edge that was always there in fact.
dependency "rds" {
  config_path = "../storage/rds"
}

terraform {
  source = "../../../../infra/aws/modules//integration"
}

generate "providers" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.cfg.aws_region}"
    }
    provider "databricks" {
      # Name the auth method explicitly: if ARM_* ever leaks into this job the
      # provider would otherwise see two credentials and refuse to choose.
      auth_type     = "oauth-m2m"
      alias         = "account"
      host          = "${local.cfg.databricks_host}"
      account_id    = "${local.cfg.dbx_account_id}"
      client_id     = var.spn_client_id
      client_secret = var.spn_client_secret
    }
    provider "time" {}
  EOF
}

inputs = {
  environment            = local.cfg.environment
  region                 = local.cfg.aws_region
  is_private_connection  = local.cfg.is_private_connection_aws
  databricks_host        = local.cfg.databricks_host
  dbx_account_id         = local.cfg.dbx_account_id
  spn_client_id          = local.spn.client_id
  spn_client_secret      = local.spn.client_secret
  vpc_id                 = dependency.network.outputs.vpc_id
  subnet_ids             = dependency.network.outputs.subnet_ids
  ecs_security_group_id  = dependency.network.outputs.ecs_security_group_id
  rds_security_group_id  = dependency.network.outputs.rds_security_group_id
  rds_secret_arn         = dependency.secrets_manager.outputs.rds_secret_arn
  rds_username           = local.cfg.rds_username
  private_dns_zone_name  = local.cfg.private_dns_zone_name
  rds_custom_dns_name    = local.cfg.rds_custom_dns_name
  ecr_repo_name          = local.cfg.ecr_repo_name
  ecs_role_arn           = dependency.iam.outputs.ecs_role_arn
  proxy_role_arn         = dependency.iam.outputs.proxy_role_arn
  db_instance_identifier = local.cfg.db_instance_identifier
  ncc_id                 = dependency.bootstrap_platform.outputs.ncc_id

  # For the gateway image's one-shot roles: a private RDS is unreachable from a CI runner by
  # construction, so the schema DDL and the seed run from inside the VPC, in this container.
  rds_hostname = dependency.rds.outputs.rds_hostname
  db_name      = local.cfg.db_name

  # The one principal allowed to put an endpoint into the PrivateLink service. Was "*".
  databricks_serverless_privatelink_account_id = local.cfg.dbx_serverless_privatelink_account_id
}
