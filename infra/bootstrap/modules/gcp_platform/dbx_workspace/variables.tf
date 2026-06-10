variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "metastore_bucket_name" {
  description = "The name of the GCS bucket for workspace root storage"
  type        = string
}

variable "workspace_name" {
  description = "The name of the workspace"
  type        = string
}

variable "location" {
  description = "The GCP region for the workspace"
  type        = string
}

variable "gcp_metastore_id" {
  description = "The ID of the Unity Catalog metastore"
  type        = string
}

variable "admin_group_id" {
  description = "The ID of the admin group to be assigned to the workspace"
  type        = string
}

variable "functional_group_ids" {
  description = "A map of functional group names to their IDs"
  type        = map(string)
}

variable "workspace_pricing_tier" {
  description = "Pricing tier (ENTERPRISE, BUSINESS_CRITICAL, etc.)"
  type        = string
  default     = "ENTERPRISE"
}

variable "environment" {
  description = "The environment suffix (e.g. dev, prod)"
  type        = string
}

variable "dbx_account_id" {
  description = "The Databricks Account ID (UUID) found in the Account Console"
  type        = string
}