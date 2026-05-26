# --- Authentication ---
variable "gcp_managed_workspace_host" {
  description = "The URL of the Databricks workspace"
  type        = string
}

variable "gcp_dbx_account_id" {
  description = "The Databricks Account ID"
  type        = string
}

variable "gcp_spn_client_id" {
  description = "Application Client ID"
  type        = string
}

variable "gcp_spn_client_secret" {
  description = "Application Client Secret"
  type        = string
  sensitive   = true
}

# --- Workspace Context ---
variable "managed_workspace_id" {
  description = "The numerical ID of the workspace for binding (e.g., 250213...)"
  type        = string
}

# --- JSON Data Inputs ---
variable "catalogs_json" {
  description = "JSON string containing federated catalog definitions"
  type        = string
}

variable "catalog_grants_json" {
  description = "JSON string containing catalog-level permissions"
  type        = string
  default     = "[]"
}

variable "binding_type" {
  description = "The access level for the binding. Default is READ_WRITE"
  type        = string
}
