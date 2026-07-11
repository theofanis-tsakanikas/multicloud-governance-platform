variable "environment" {
  description = "Environment name (dev|prod)."
  type        = string
}

variable "region" {
  description = "AWS region hosting the private-mode VPC."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group from the foundation layer."
  type        = string
}

variable "vnet_name" {
  description = "Name of the Azure virtual network."
  type        = string
}

variable "azure_vnet_cidr" {
  description = "Address space of the VNet."
  type        = list(string)
}

variable "data_subnet_prefix" {
  description = "Address prefix of the data subnet."
  type        = list(string)
}

variable "endpoint_subnet_prefix" {
  description = "Address prefix of the private-endpoint subnet."
  type        = list(string)
}

variable "gateway_subnet_prefix" {
  description = "Address prefix of the reserved GatewaySubnet."
  type        = list(string)
}

variable "databricks_vpc_cidr" {
  description = "CIDR of the AWS Databricks VPC, allowed through the SQL NSG."
  type        = string
}

variable "databricks_subnets" {
  description = "Subnets of the private-mode AWS VPC."
  type        = map(string)
}

variable "key_vault_id" {
  description = "Key Vault from the foundation layer. Reserved for the VPN shared key in private mode."
  type        = string
  default     = null
}

variable "is_private_connection" {
  description = "Private mode builds the cross-cloud VPN: the Azure gateway and the whole AWS-side VPC (NAT gateway included)."
  type        = bool
  default     = false
}

variable "ecr_repo_name" {
  description = "ECR repository name for the SQL transit gateway image (private mode)."
  type        = string
  default     = "sql-gateway"
}
