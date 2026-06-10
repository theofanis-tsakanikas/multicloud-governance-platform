# Provider for GCP (The Data Provider side)


# Provider for AWS (The Data Recipient side)



# 1. Create the Share and Recipient on the GCP side
# This module defines which tables are shared and authorizes the AWS Metastore ID as a recipient.
module "gcp_side" {
  source                  = "./dbx_delta_sharing/gcp_side"
  providers               = { databricks = databricks.gcp }
  delta_shares_map_json   = var.delta_shares_map_json
  aws_global_metastore_id = var.aws_global_metastore_id
}

# 2. Mount the GCP Share as a Catalog in AWS
# This module creates a 'Provider' object and a shared catalog in the AWS environment.
module "aws_catalog_mount" {
  source                = "./dbx_delta_sharing/aws_catalog_mount"
  providers             = { databricks = databricks.aws }
  delta_shares_map_json = var.delta_shares_map_json
  gcp_metastore_id      = var.gcp_metastore_id
  gcp_provider_name     = var.gcp_provider_name

  # Ensure the GCP Share exists before attempting to mount it in AWS
  depends_on = [module.gcp_side]
}