resource "time_sleep" "wait_after_metastore" {
  depends_on      = [module.dbx_metastore]
  create_duration = "60s"
}

# This GCP Databricks account is SEPARATE from the AWS one, so it needs its own
# admin + functional groups (the AWS shared_identities groups live in the AWS
# account). Created here with the account-scoped mws provider, before the
# metastore (which owns to the admin group) and the workspace (which assigns them).
resource "databricks_group" "admins" {
  provider     = databricks.mws
  display_name = var.admin_group_name
}

resource "databricks_group_role" "admins_account_admin" {
  provider = databricks.mws
  group_id = databricks_group.admins.id
  role     = "account_admin"
}

resource "databricks_group_member" "admin_members" {
  provider  = databricks.mws
  for_each  = toset(var.metastore_admins)
  group_id  = databricks_group.admins.id
  member_id = each.key
}

resource "databricks_group" "functional" {
  provider     = databricks.mws
  for_each     = toset(var.identity_groups)
  display_name = each.value
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
  depends_on                   = [databricks_group.admins]
}

module "dbx_workspace" {
  source                 = "./dbx_workspace"
  project_id             = var.project_id
  metastore_bucket_name  = var.metastore_bucket_name
  workspace_name         = var.workspace_name
  location               = var.location
  gcp_metastore_id       = module.dbx_metastore.gcp_metastore_id
  admin_group_id         = databricks_group.admins.id
  functional_group_ids   = { for k, g in databricks_group.functional : k => g.id }
  workspace_pricing_tier = var.workspace_pricing_tier
  environment            = var.environment
  dbx_account_id         = var.gcp_dbx_account_id
  providers              = { databricks = databricks.mws }
  depends_on             = [time_sleep.wait_after_metastore]
}
