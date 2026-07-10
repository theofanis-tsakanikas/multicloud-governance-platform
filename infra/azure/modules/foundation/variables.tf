variable "environment" {
  description = "Environment name (dev|prod)."
  type        = string
}

variable "location" {
  description = "Azure region for every resource in this layer."
  type        = string
}

variable "prefix_key_vault_name" {
  description = "Prefix for the Key Vault; the layer appends the environment and a random suffix."
  type        = string
}

variable "admin_object_id" {
  description = "AAD object id granted admin access to the Key Vault."
  type        = string
}

variable "orchestrator_object_id" {
  description = "AAD object id of the identity running Terraform (needs to write secrets at apply time)."
  type        = string
}

variable "adls_name" {
  description = "Globally-unique name of the ADLS Gen2 storage account."
  type        = string
}

variable "azure_containers" {
  description = "Containers to create inside the storage account."
  type        = list(string)
}
