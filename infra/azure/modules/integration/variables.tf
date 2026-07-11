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

# ── Transit-hub additions (private mode only) ─────────────────────────────────────────────────

variable "subnet_ids" {
  description = "AWS private subnets (from network/aws_network) where the SQL gateway NLB and Fargate task run."
  type        = list(string)
  default     = []
}

variable "security_group_id" {
  description = "Security group for the SQL gateway Fargate task (aws_network's databricks_sg)."
  type        = string
  default     = ""
}

variable "ecr_repo_name" {
  description = "ECR repository holding the sql-gateway image (created in the network layer)."
  type        = string
  default     = ""
}

variable "ncc_id" {
  description = "Databricks Network Connectivity Config id (from bootstrap/aws/platform)."
  type        = string
  default     = ""
}

variable "dbx_account_id" {
  description = "Databricks account id (UUID) for the NCC private-endpoint rule."
  type        = string
  default     = ""
}

variable "databricks_serverless_privatelink_account_id" {
  description = "Databricks' serverless-PrivateLink AWS account id — the only principal allowed into the gateway's endpoint service."
  type        = string
  default     = ""
}

variable "spn_client_id" {
  description = "Databricks account SPN client id, for the account-level provider that creates the NCC rule."
  type        = string
  default     = ""
}

variable "spn_client_secret" {
  description = "Databricks account SPN client secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "databricks_host" {
  description = "Databricks accounts host (accounts.cloud.databricks.com)."
  type        = string
  default     = ""
}
