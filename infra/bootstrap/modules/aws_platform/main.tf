resource "time_sleep" "wait_after_metastore" {
  depends_on      = [module.dbx_metastore]
  create_duration = "60s"
}

module "dbx_metastore" {
  source                       = "./dbx_metastore"
  region                       = var.region
  metastore_name               = var.metastore_name
  metastore_storage_root       = "s3://${var.metastore_bucket_name}"
  delta_sharing_token_lifetime = var.delta_sharing_token_lifetime
  admin_group_name             = var.admin_group_name
  metastore_iam_role_arn       = var.metastore_iam_role_arn
  admin_group_id               = var.admin_group_id
  delta_sharing_name           = var.delta_sharing_name
  providers                    = { databricks = databricks.mws }
}

module "dbx_workspace" {
  source                 = "./dbx_workspace"
  dbx_account_id         = var.dbx_account_id
  workspace_name         = var.workspace_name
  environment            = var.environment
  region                 = var.region
  workspace_pricing_tier = var.workspace_pricing_tier
  cross_account_role_arn = var.cross_account_role_arn
  metastore_bucket_name  = var.metastore_bucket_name
  admin_group_id         = var.admin_group_id
  functional_group_ids   = var.functional_group_ids
  metastore_id           = module.dbx_metastore.metastore_id
  providers              = { databricks = databricks.mws }
  depends_on             = [time_sleep.wait_after_metastore]
}
