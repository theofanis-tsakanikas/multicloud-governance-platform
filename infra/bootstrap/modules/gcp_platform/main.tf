resource "time_sleep" "wait_after_metastore" {
  depends_on      = [module.dbx_metastore]
  create_duration = "60s"
}

module "dbx_metastore" {
  source                       = "./dbx_metastore"
  location                     = var.location
  metastore_name               = var.gcp_metastore_name
  metastore_storage_root       = "gs://${var.metastore_bucket_name}"
  delta_sharing_token_lifetime = var.delta_sharing_token_lifetime
  admin_group_name             = var.admin_group_name
  dbx_sa_email                 = var.dbx_sa_email
  metastore_bucket_name        = var.metastore_bucket_name
  dbx_sa_id                    = var.dbx_sa_id
  gcp_delta_sharing_name       = var.gcp_delta_sharing_name
  providers                    = { databricks = databricks.mws }
}

module "dbx_workspace" {
  source                 = "./dbx_workspace"
  project_id             = var.project_id
  metastore_bucket_name  = var.metastore_bucket_name
  workspace_name         = var.workspace_name
  location               = var.location
  gcp_metastore_id       = module.dbx_metastore.gcp_metastore_id
  admin_group_id         = var.admin_group_id
  functional_group_ids   = var.functional_group_ids
  workspace_pricing_tier = var.workspace_pricing_tier
  environment            = var.environment
  dbx_account_id         = var.gcp_dbx_account_id
  providers              = { databricks = databricks.mws }
  depends_on             = [time_sleep.wait_after_metastore]
}
