variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "location" {
  description = "Region (kept for parity with the other layers)."
  type        = string
  default     = null
}

variable "gcs_bucket_name" {
  description = "Bucket the Databricks identities are granted access to."
  type        = string
}

variable "dbx_sa_email" {
  description = "Service account of the Databricks workspace, from the GCP bootstrap."
  type        = string
}

variable "uc_sa_email" {
  description = "Unity Catalog's Google-managed service account for this Databricks account."
  type        = string
}

variable "provider_key" {
  description = "Seed service-account key, consumed by the generated provider block."
  type        = string
  sensitive   = true
  default     = null
}
