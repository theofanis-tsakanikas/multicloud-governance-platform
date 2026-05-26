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
