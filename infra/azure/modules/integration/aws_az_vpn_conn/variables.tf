# --- AWS Connectivity Inputs ---
variable "aws_vpn_gw_id" {
  description = "The ID of the AWS Virtual Private Gateway"
  type        = string
}

variable "databricks_vpc_cidr" {
  description = "The CIDR block of the AWS VPC (e.g., 10.10.0.0/16)"
  type        = string
}

# --- Azure Connectivity Inputs ---
variable "azure_vpn_public_ip" {
  description = "The Public IP address of the Azure Virtual Network Gateway"
  type        = string
}

variable "azure_vpn_gw_id" {
  description = "The ID of the Azure Virtual Network Gateway"
  type        = string
}

variable "azure_vnet_cidr" {
  description = "The CIDR block of the Azure VNet (e.g., 10.20.0.0/16)"
  type        = list(string)
}

# --- Resource Metadata & Security ---
variable "location" {
  description = "The Azure region where the resources are located"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the Azure resource group"
  type        = string
}

variable "shared_key" {
  description = "The Pre-Shared Key (PSK) used for the IPSec VPN tunnel"
  type        = string
  sensitive   = true
}

variable "sql_server_fqdn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_ip_address" {
  type = string
}