variable "environment" {
  description = "Environment name (dev|prod)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "region" {
  description = "AWS region hosting the Databricks VPC."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group from the foundation layer."
  type        = string
}

variable "is_private_connection" {
  description = "When false this layer is a no-op: no private endpoint, no VPN."
  type        = bool
  default     = false
}

variable "vnet_id" {
  description = "VNet the private DNS zone is linked to."
  type        = string
}

variable "endpoint_subnet_id" {
  description = "Subnet the private endpoint's NIC lands in."
  type        = string
}

# ── Private mode only. Null in public mode, where nothing consumes them. ──────
variable "sql_server_name" {
  description = "SQL server to expose through Private Link (private mode only)."
  type        = string
  default     = null
}

variable "sql_server_id" {
  description = "SQL server resource id (private mode only)."
  type        = string
  default     = null
}

variable "sql_server_fqdn" {
  description = "SQL server FQDN, resolved to the private IP by the VPN's DNS (private mode only)."
  type        = string
  default     = null
}

variable "azure_vnet_cidr" {
  description = "VNet address space announced across the tunnel (private mode only)."
  type        = list(string)
  default     = []
}

variable "databricks_vpc_cidr" {
  description = "AWS VPC CIDR announced across the tunnel (private mode only)."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "AWS VPC id (private mode only)."
  type        = string
  default     = null
}

variable "aws_vpn_gw_id" {
  description = "AWS VPN gateway id (private mode only)."
  type        = string
  default     = null
}

variable "azure_vpn_public_ip" {
  description = "Azure VPN gateway public IP (private mode only)."
  type        = string
  default     = null
}

variable "azure_vpn_gw_id" {
  description = "Azure VPN gateway id (private mode only)."
  type        = string
  default     = null
}

variable "vpn_shared_key" {
  description = "Pre-shared key for the IPsec tunnel (private mode only)."
  type        = string
  default     = null
  sensitive   = true
}
