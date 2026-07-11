locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "rds_gateway" {
  for_each               = local.private_mode
  source                 = "./_components/rds_gateway"
  environment            = var.environment
  region                 = var.region
  vpc_id                 = var.vpc_id
  subnet_ids             = var.subnet_ids
  ecs_security_group_id  = var.ecs_security_group_id
  rds_secret_arn         = var.rds_secret_arn
  rds_username           = var.rds_username
  private_dns_zone_name  = var.private_dns_zone_name
  rds_custom_dns_name    = var.rds_custom_dns_name
  ecr_repo_name          = var.ecr_repo_name
  ecs_role_arn           = var.ecs_role_arn
  db_instance_identifier = var.db_instance_identifier
  rds_security_group_id  = var.rds_security_group_id
  proxy_role_arn         = var.proxy_role_arn

  rds_hostname                                 = var.rds_hostname
  db_name                                      = var.db_name
  databricks_serverless_privatelink_account_id = var.databricks_serverless_privatelink_account_id
}

resource "time_sleep" "dns_propagation" {
  for_each        = local.private_mode
  depends_on      = [module.rds_gateway]
  create_duration = "60s"
}

module "aws_rds_ncc_rule" {
  for_each              = local.private_mode
  source                = "./_components/aws_rds_ncc_rule"
  ncc_id                = var.ncc_id
  endpoint_service_name = module.rds_gateway["enabled"].endpoint_service_name
  rds_custom_dns_name   = var.rds_custom_dns_name
  databricks_account_id = var.dbx_account_id

  providers = {
    databricks = databricks.account
  }

  depends_on = [time_sleep.dns_propagation]
}

# Creating the NCC rule is not the same as the endpoint being usable. Databricks provisions an
# interface endpoint into our VPC endpoint service on its own side; the service auto-accepts
# (acceptance_required = false), but the endpoint sits PENDING for a few minutes and only then
# does `postgres.db.internal` resolve from serverless compute.
#
# The layer that finds out is dbx_rds_grants, three layers later, which warms the foreign
# catalog by actually querying Postgres. It would fail with "Schema does not exist" — an error
# that says nothing about a private endpoint still coming up, and costs a full re-run to
# understand. Wait here, where the reason is legible, rather than there, where it is not.
resource "time_sleep" "ncc_endpoint_ready" {
  for_each        = local.private_mode
  depends_on      = [module.aws_rds_ncc_rule]
  create_duration = "180s"
}
