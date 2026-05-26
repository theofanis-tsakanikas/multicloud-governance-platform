variable "resource_group_name" {
  description = "Name of the existing resource group"
  type        = string
}

variable "location" {
  description = "Azure region (e.g., North Europe)"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "azure_vnet_cidr" {
  description = "Address space for the VNet"
  type        = list(string)
}

variable "data_subnet_prefix" {
  description = "Address prefix for the data subnet"
  type        = list(string)
}

variable "endpoint_subnet_prefix" {
  description = "Address prefix for the private endpoints subnet"
  type        = list(string)
}

variable "databricks_vpc_cidr" {
  description = "The CIDR block for the Databricks Classic VPC."
  type        = string
}

variable "gateway_subnet_prefix" {
  description = "The address prefix for the dedicated GatewaySubnet used by the Azure Virtual Network Gateway."
  type        = list(string)
}