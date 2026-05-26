# --- Databricks Provider Variables ---

variable "gcp_serverless_workspace_host" {
  description = "The DNS URL of the Databricks Workspace (e.g., https://adb-xxx.azuredatabricks.net)."
  type        = string
}

variable "gcp_dbx_account_id" {
  description = "The Databricks Account ID (required for Unity Catalog operations)."
  type        = string
}

variable "gcp_spn_client_id" {
  description = "The Client ID of the Service Principal used for Databricks auth."
  type        = string
}

variable "gcp_spn_client_secret" {
  description = "The Client Secret of the Service Principal used for Databricks auth."
  type        = string
  sensitive   = true
}

# --- Connection Variables ---

variable "connection_name" {
  description = "The name of the BigQuery connection in Unity Catalog."
  type        = string
}

variable "project_id" {
  description = "The ID of the Google Cloud Project"
  type        = string
  default     = "databricks-multicloud-platform"
}

variable "cred_sa_email" {
  type        = string
  description = "The email address of the Google Service Account created during bootstrap (the output dbx_sa_email)."
}

variable "bq_key" {
  type        = string
  description = "The JSON service account key for BigQuery connection"
  sensitive   = true
}

variable "admin_group_name" {
  description = "The display name of the admin group (e.g., 'metastore_admins') used for Unity Catalog grants."
  type        = string
}
