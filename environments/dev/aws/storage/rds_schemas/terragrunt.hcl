include "root" {
  path = find_in_parent_folders()
}

locals {
  cfg = read_terragrunt_config(find_in_parent_folders("config.hcl")).locals

  rds_secret = jsondecode(run_cmd(
    "aws", "secretsmanager", "get-secret-value",
    "--secret-id", local.cfg.password_name,
    "--query", "SecretString",
    "--output", "text",
    "--region", local.cfg.aws_region
  ))

  # Extract federated catalog schemas from domain definition
  domain         = jsondecode(file("${get_terragrunt_dir()}/../../domains/aws/sales_infra.json"))
  fed_catalogs   = [for c in local.domain.catalogs : c if c.type == "FEDERATED"]
  schemas_to_create = flatten([
    for cat in local.fed_catalogs : [
      for s in lookup(cat, "schemas", []) : s.schema_name
    ]
  ])
}

dependency "rds" {
  config_path = "../rds"
}

terraform {
  source = "../../../../../infra/aws/modules/storage//rds_schemas"
}

generate "provider_postgresql" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "postgresql" {
      host            = "${dependency.rds.outputs.rds_hostname}"
      port            = ${local.cfg.rds_port}
      database        = "${local.cfg.db_name}"
      username        = "${local.cfg.rds_username}"
      password        = var.password
      sslmode         = "require"
      connect_timeout = 15
    }
  EOF
}

inputs = {
  rds_hostname = dependency.rds.outputs.rds_hostname
  db_name      = local.cfg.db_name
  rds_username = local.cfg.rds_username
  password     = local.rds_secret.password
  rds_port     = local.cfg.rds_port
  rds_schemas  = local.schemas_to_create
}
