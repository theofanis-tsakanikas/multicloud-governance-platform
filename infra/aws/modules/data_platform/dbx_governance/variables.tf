# --- Databricks Connection & Auth ---
variable "serverless_workspace_host" {
  type        = string
  description = "The URL of the Databricks workspace"
}

variable "dbx_account_id" {
  type        = string
  description = "The Databricks Account ID"
}

variable "spn_client_id" {
  type        = string
  description = "Service Principal Client ID"
}

variable "spn_client_secret" {
  type        = string
  description = "Service Principal Client Secret"
  sensitive   = true
}

# --- AWS Infrastructure References ---
variable "bucket_name" {
  type        = string
  description = "The name of the S3 bucket (e.g., project-data-bucket)"
}

variable "storage_credential_name" {
  type        = string
  description = "The name of the Databricks Storage Credential to use"
}

variable "managed_storage_root" {
  type        = string
  description = "Default S3 path for managed catalogs if not specified in JSON"
}


# --- JSON Strings (Orchestration Data) ---
variable "external_locations_json" {
  type        = string
  description = "JSON array of external locations configuration"
}

variable "catalogs_json" {
  type        = string
  description = "JSON array of all catalogs (Managed & Federated)"
}

variable "ext_loc_grants_json" {
  type        = string
  description = "JSON array of grants for external locations"
}

variable "catalog_grants_json" {
  type        = string
  description = "JSON array of grants for catalogs"
}

variable "managed_schema_grants_json" {
  type        = string
  description = "JSON array of grants for schemas"
}

variable "volume_grants_json" {
  type        = string
  description = "JSON array of grants for volumes"
}

