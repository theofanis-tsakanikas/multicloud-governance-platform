





locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "dbx_workspace" {
  for_each = local.private_mode

  source = "./dbx_workspace"

  dbx_aws_account_id     = var.dbx_aws_account_id
  dbx_account_id         = var.dbx_account_id
  managed_workspace_name = var.managed_workspace_name
  region                 = var.region
  vpc_id                 = var.vpc_id
  private_subnet_ids     = var.private_subnet_ids
  security_group_id      = var.security_group_id
  metastore_id           = var.metastore_id
  providers = {
    databricks = databricks.mws
  }
}