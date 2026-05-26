variable "key_vault_name" {
  type        = string
  description = "The name of the Key Vault. Must be globally unique across Azure."
}

variable "location" {
  type        = string
  description = "The Azure region where the Key Vault will be created."
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group in which to create the Key Vault."
}

variable "object_id" {
  type        = string
  description = "The object ID of a user, service principal or security group in the Azure Active Directory tenant for the access policy."
}

variable "orchestrator_object_id" {
  type        = string
  description = "The Client ID of the Python Orchestrator"
}