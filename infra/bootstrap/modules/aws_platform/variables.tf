variable "databricks_host" { type = string }
variable "dbx_account_id" { type = string }
variable "spn_client_id" { type = string }
variable "spn_client_secret" {
  type      = string
  sensitive = true
}
variable "region" { type = string }
variable "environment" { type = string }
variable "metastore_name" { type = string }
variable "metastore_bucket_name" { type = string }
variable "metastore_iam_role_arn" { type = string }
variable "delta_sharing_token_lifetime" {
  type    = number
  default = 0
}
variable "delta_sharing_name" { type = string }
variable "workspace_name" { type = string }
variable "workspace_pricing_tier" {
  type    = string
  default = "ENTERPRISE"
}
variable "cross_account_role_arn" { type = string }
variable "admin_group_name" { type = string }
variable "admin_group_id" { type = string }
variable "functional_group_ids" { type = map(string) }
