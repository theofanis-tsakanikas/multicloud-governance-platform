# 1. Metastore Creation (Unity Catalog)
resource "databricks_metastore" "this" {
  name = var.metastore_name
  # The S3 path used for managed tables (e.g., s3://bucket-name/metastore)
  storage_root  = var.metastore_storage_root
  region        = var.region
  force_destroy = false

  # Delta Sharing settings (Senior Practice)
  # Enables secure data exchange within and outside the organization
  delta_sharing_organization_name                   = var.delta_sharing_name
  delta_sharing_scope                               = "INTERNAL_AND_EXTERNAL"
  delta_sharing_recipient_token_lifetime_in_seconds = var.delta_sharing_token_lifetime

  # Assigns administrative ownership to the designated Admin Group
  owner = var.admin_group_name
}



# 2. Linking the IAM Role with the Metastore (Data Access)
# This resource bridges the Databricks Metastore with your AWS IAM Role
resource "databricks_metastore_data_access" "this" {
  metastore_id = databricks_metastore.this.id
  name         = "metastore-data-access-v2"
  # Sets this as the default credential for the metastore
  is_default = true

  # Reference to the IAM Role ARN created in the security module
  aws_iam_role {
    role_arn = var.metastore_iam_role_arn
  }
}