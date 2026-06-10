# --- Databricks Connection Variables ---
variable "gcp_serverless_workspace_host" {
  description = "The URL of the Databricks workspace"
  type        = string
}

variable "gcp_dbx_account_id" {
  description = "The Databricks account ID (required for UC admin operations)"
  type        = string
}

variable "gcp_spn_client_id" {
  description = "Application Client ID for the Databricks provider"
  type        = string
}

variable "gcp_spn_client_secret" {
  description = "Application Client Secret for the Databricks provider"
  type        = string
  sensitive   = true
}

# --- JSON Strings from Python Orchestrator ---
# These variables receive JSON-encoded strings from the Terragrunt inputs
variable "external_locations_json" {
  description = "JSON string containing external locations definitions"
  type        = string
}

variable "ext_loc_grants_json" {
  description = "JSON string containing grants for external locations"
  type        = string
}

variable "catalogs_json" {
  description = "JSON string containing managed and federated catalogs definitions"
  type        = string
}

variable "catalog_grants_json" {
  description = "JSON string containing catalog-level grants"
  type        = string
}

variable "managed_schema_grants_json" {
  description = "JSON string containing schema-level grants"
  type        = string
}

variable "volume_grants_json" {
  description = "JSON string containing volume-level grants"
  type        = string
}

# --- Global Governance Variables ---
variable "managed_storage_root" {
  description = "The base path for managed storage (e.g., container/folder)"
  type        = string
}


variable "deployment_id_gcp" {
  type        = string
  description = "Unique hash or generation ID provided by the orchestrator. Changing this forces a new name for external locations, avoiding API cache issues (ghosting) after a destroy."
}

variable "storage_credential_name" {
  description = "The name of the storage credential to use"
  type        = string
}

variable "bucket_name" {
  type = string
}