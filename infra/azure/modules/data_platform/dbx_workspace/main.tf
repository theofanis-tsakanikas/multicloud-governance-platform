# Account Provider (Alias) - For Metastore, NCC, and Groups management






locals {
  # If true, we create a map with a single key "enabled".
  # If false, the map is empty {}.
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}



module "dbx_workspace" {
  # Key logic: If the map is empty, the module is not deployed (count = 0 equivalent)
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
  
  # Passing the account-level alias to the module for identity/NCC operations
  providers = {
    databricks = databricks.mws
  }
}