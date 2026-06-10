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
}

variable "azure_storage_credential_name" {
  type = string
}

variable "deployment_id" {
  type        = string
  description = "Unique hash or generation ID provided by the orchestrator. Changing this forces a new name for external locations, avoiding API cache issues (ghosting) after a destroy."
}