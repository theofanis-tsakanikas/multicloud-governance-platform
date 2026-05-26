variable "resource_group_name" {
  description = "The name of the resource group where resources will be created"
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
}

variable "sql_server_name" {
  description = "The name of the SQL Server used for naming the private endpoint"
  type        = string
}

variable "sql_server_id" {
  description = "The resource ID of the SQL Server to be connected via Private Endpoint"
  type        = string
}

variable "vnet_id" {
  description = "The resource ID of the Virtual Network where the DNS Zone will be linked"
  type        = string
}

variable "endpoint_subnet_id" {
  description = "The ID of the specific subnet where the Private Endpoint NIC will be placed"
  type        = string
}