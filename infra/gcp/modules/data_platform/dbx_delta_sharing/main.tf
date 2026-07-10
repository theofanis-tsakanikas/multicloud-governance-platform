# Provider for GCP (The Data Provider side)


# Provider for AWS (The Data Recipient side)



# 1. Create the Share and Recipient on the GCP side
# This module defines which tables are shared and authorizes the AWS Metastore ID as a recipient.
module "gcp_side" {
  source                  = "./gcp_side"
  providers               = { databricks = databricks.gcp_mws }
  delta_shares_map_json   = var.delta_shares_map_json
  aws_global_metastore_id = var.aws_global_metastore_id
  aws_db_recipient        = var.aws_db_recipient
}

# 2. Mount the GCP Share as a Catalog in AWS
# This module creates a 'Provider' object and a shared catalog in the AWS environment.
module "aws_catalog_mount" {
  source                = "./aws_catalog_mount"
  providers             = { databricks = databricks.aws_mws }
  delta_shares_map_json = var.delta_shares_map_json
  gcp_metastore_id      = var.gcp_metastore_id
  gcp_provider_name     = var.gcp_provider_name

  # Ensure the GCP Share exists before attempting to mount it in AWS
  depends_on = [module.gcp_side]
}