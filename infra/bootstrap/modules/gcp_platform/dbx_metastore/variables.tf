variable "metastore_name" {
  description = "The name of the Unity Catalog Metastore"
  type        = string
}

variable "metastore_storage_root" {
  description = "The GCS bucket path for the metastore (gs://bucket/path)"
  type        = string
}

variable "location" {
  description = "The GCP region for the metastore"
  type        = string
}

variable "dbx_sa_email" {
  description = "The email of the Google Service Account for data access"
  type        = string
}

variable "delta_sharing_token_lifetime" {
  description = "Recipient token lifetime in seconds"
  type        = number
  default     = 7776000 # 90 days
}

variable "admin_group_name" {
  description = "The group name that will own the metastore"
  type        = string
}

variable "metastore_bucket_name" {
  description = "The name of the GCS bucket for workspace root storage"
  type        = string
}

variable "dbx_sa_id" {
  type        = string
  description = "The full resource ID of the created Google Service Account"
}

variable "gcp_delta_sharing_name" {
  type        = string
  description = "The unique name for this Metastore in the Delta Sharing ecosystem. It will appear as the Provider name on the consumer side (AWS)."
}