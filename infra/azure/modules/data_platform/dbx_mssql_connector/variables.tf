# --- Databricks Provider Variables (AWS) ---
variable "dbx_workspace_host" {
  type        = string
  description = "The URL of the Databricks workspace (e.g., https://dbc-xxxx.cloud.databricks.com)"
}

variable "dbx_account_id" {
  type        = string
  description = "The Databricks Account ID."
}

variable "spn_client_id" {
  type        = string
  description = "Client ID for Databricks authentication."
}

variable "spn_client_secret" {
  type        = string
  description = "Client Secret for Databricks authentication."
  sensitive   = true
}

# --- Azure SQL Connection Variables ---
variable "sql_server_host" {
  type        = string
  description = "The host of the Azure SQL Server"
}

variable "sql_admin_user" {
  type        = string
  description = "Admin username for the SQL Server."
}

variable "sql_admin_password" {
  type        = string
  description = "The actual password fetched from Key Vault via Python."
  sensitive   = true
}

variable "sql_password_name" {
  type        = string
  description = "The key name to be used inside Databricks Secrets."
}

variable "connection_name" {
  type        = string
  description = "Name of the external connection in Unity Catalog."
}

variable "sql_database_name" {
  type        = string
  description = "Default/Master database for the connection handshake."
}
