variable "environment" { type = string }
variable "region" { type = string }
variable "databricks_host" { type = string }
variable "dbx_account_id" { type = string }
variable "dbx_aws_account_id" { type = string }
variable "metastore_bucket_name" { type = string }
variable "metastore_iam_role_name" { type = string }
variable "cross_account_role_name" { type = string }
variable "secret_base_path" { type = string }
variable "secret_recovery_window" { type = number }
variable "kms_deletion_window" { type = number }
variable "spn_suffix" { type = string }
variable "admin_group_name" { type = string }
variable "metastore_admins" { type = list(string) }
variable "identity_groups" { type = list(string) }
variable "initial_client_id" { type = string }
variable "initial_client_secret" {
  type      = string
  sensitive = true
}
