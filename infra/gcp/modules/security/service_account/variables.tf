variable "project_id" {
  description = "The ID of the Google Cloud Project where security resources will be created."
  type        = string
}

variable "gcs_bucket_name" {
  description = "The name of the existing bucket from Foundation level"
  type        = string
}

variable "dbx_sa_email" {
  type        = string
  description = "The email address of the Google Service Account created during bootstrap (the output dbx_sa_email)."
}

variable "uc_sa_email" {
  type        = string
  description = "The System-Managed Service Account email provided by Databricks Metastore"
}
variable "federation_sa_id" {
  description = "Account id of the BigQuery federation service account."
  type        = string
}

variable "bq_secret_id" {
  description = "Secret Manager secret holding the federation SA key."
  type        = string
}
