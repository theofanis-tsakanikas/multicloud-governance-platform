variable "gcp_databricks_host" { type = string }
variable "gcp_dbx_account_id" { type = string }
variable "gcp_spn_client_id" { type = string }
variable "gcp_spn_client_secret" {
  type      = string
  sensitive = true
}
variable "provider_key" {
  type      = string
  sensitive = true
}
variable "project_id" { type = string }
variable "location" { type = string }
variable "environment" { type = string }
variable "gcp_metastore_name" { type = string }
variable "metastore_bucket_name" { type = string }
variable "dbx_sa_email" { type = string }
variable "dbx_sa_id" { type = string }
variable "delta_sharing_token_lifetime" {
  type    = number
  default = 0
}
variable "gcp_delta_sharing_name" { type = string }
variable "workspace_name" { type = string }
variable "workspace_pricing_tier" {
  type    = string
  default = "ENTERPRISE"
}
variable "admin_group_name" { type = string }
variable "admin_group_id" { type = string }
variable "functional_group_ids" { type = map(string) }
