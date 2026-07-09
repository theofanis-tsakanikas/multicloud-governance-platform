variable "serverless_workspace_host" {
  description = "The Databricks workspace URL"
  type        = string
}

variable "dbx_account_id" {
  description = "The Databricks Account ID"
  type        = string
}

variable "spn_client_id" {
  type      = string
  sensitive = true
}

variable "spn_client_secret" {
  type      = string
  sensitive = true
}

# --- JSON Input Variables (From Python) ---

variable "federated_catalogs_json" {
  description = "JSON string containing the list of federated catalogs"
  type        = string
}

variable "federated_schema_grants_json" {
  description = "JSON string containing the filtered federated schema grants"
  type        = string
}

variable "warehouse_id" {
  description = "SQL warehouse used to warm the foreign catalog before applying grants"
  type        = string
}
