resource "time_sleep" "iam_propagation" {
  create_duration = "60s"
  triggers        = { role_arn = module.aws_infra.cross_account_role_arn }
}

module "aws_infra" {
  source                  = "./aws_infra"
  environment             = var.environment
  region                  = var.region
  dbx_aws_account_id      = var.dbx_aws_account_id
  dbx_account_id          = var.dbx_account_id
  metastore_bucket_name   = var.metastore_bucket_name
  metastore_iam_role_name = var.metastore_iam_role_name
  cross_account_role_name = var.cross_account_role_name
}

module "secrets_manager" {
  source                 = "../shared_secrets"
  environment            = var.environment
  secret_base_path       = var.secret_base_path
  secret_recovery_window = var.secret_recovery_window
  kms_deletion_window    = var.kms_deletion_window
}

module "dbx_identities" {
  source           = "../shared_identities"
  environment      = var.environment
  spn_suffix       = var.spn_suffix
  dbx_account_id   = var.dbx_account_id
  spn_secret_arn   = module.secrets_manager.spn_secret_arn
  admin_group_name = var.admin_group_name
  metastore_admins = var.metastore_admins
  identity_groups  = var.identity_groups

  providers = { databricks = databricks.mws }
}
