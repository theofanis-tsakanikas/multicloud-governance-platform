variable "environment" {
  description = "The environment (e.g., dev, test, prod)."
  type        = string
}

variable "databricks_application_id" {
  description = "The id of the application for the databricks connection"
  type        = string
}

variable "key_vault_id" {
  description = "The ID of the existing Azure Key Vault to store the VPN shared key."
  type        = string
}