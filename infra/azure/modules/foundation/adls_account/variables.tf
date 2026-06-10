variable "adls_name" {
  description = "The name of the adls"
  type        = string
}

variable "azure_containers" {
  description = "The azure containers"
  type        = list(string)
}

variable "resource_group_name" {
  type        = string
  description = "The name of the existing Resource Group where the SQL Server will be deployed."
}

variable "resource_group_location" {
  type        = string
  description = "The Azure region where the Resource Group is located (e.g., West Europe)."
}