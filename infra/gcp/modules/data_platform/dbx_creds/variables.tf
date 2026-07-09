variable "dbx_sa_email" {
  type        = string
  description = "The email address of the Google Service Account created during bootstrap (the output dbx_sa_email)."
}

variable "gcp_storage_credential_name" {
  type        = string
  description = "The base name for the Databricks Storage Credential."
  default     = "gcs_storage_credential"
}


variable "admin_group_name" {
  type        = string
  description = "The name of the Databricks group that will be granted ALL_PRIVILEGES on the storage credential."
}

variable "gcs_bucket_name" {
  description = "The name of the existing bucket from Foundation level"
  type        = string
}

variable "dbx_sa_id" {
  type        = string
  description = "The full resource ID of the Google Service Account (provided by the bootstrap output), used for IAM impersonation."
}

variable "project_id" {
  description = "The ID of the Google Cloud Project where security resources will be created."
  type        = string
}
variable "spn_client_id" {
  description = "Databricks automation SP client id (for the generated UC provider)."
  type        = string
}
variable "spn_client_secret" {
  description = "Databricks automation SP client secret (for the generated UC provider)."
  type        = string
  sensitive   = true
}
