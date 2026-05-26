variable "databricks_app_name" {
  description = "Base name for the Azure AD application."
  type        = string
  default     = "databricks-uc-connector"
}

variable "key_vault_id" {
  description = "The ID of the existing Azure Key Vault to store the VPN shared key."
  type        = string
}