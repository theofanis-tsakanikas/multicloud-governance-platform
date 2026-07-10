variable "environment" {
  description = "Environment name (dev|prod)."
  type        = string
}

variable "location" {
  description = "Azure region (kept for parity with the other layers)."
  type        = string
  default     = null
}

variable "databricks_app_name" {
  description = "Display name of the AAD app registration Unity Catalog authenticates as."
  type        = string
}

variable "adls_account_id" {
  description = "Storage account the SPN is granted data-plane roles on."
  type        = string
}

variable "role_names" {
  description = "Azure built-in roles to assign to the SPN on the storage account."
  type        = list(string)
}

variable "key_vault_id" {
  description = "Key Vault the app's client id and secret are written to."
  type        = string
}
