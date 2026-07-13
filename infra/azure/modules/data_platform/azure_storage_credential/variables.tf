variable "azure_tenant_id" {
  description = "The id of the azure tenant"
  type        = string
}

variable "az_spn_client_id" {
  description = "The id of the azure spn client"
  type        = string
}

variable "az_spn_client_secret" {
  description = "The secret of the azure spn client"
  type        = string
  sensitive   = true # every other *_secret/password var in the tree is; this one was missed
}

variable "azure_storage_credential_name" {
  type = string
}


variable "spn_client_id" {
  description = "Databricks automation SP client id (for the generated UC provider)."
  type        = string
}
variable "spn_client_secret" {
  description = "Databricks automation SP client secret (for the generated UC provider)."
  type        = string
  sensitive   = true
}
