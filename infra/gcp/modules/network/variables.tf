variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "location" {
  description = "GCP region."
  type        = string
}

variable "region" {
  description = "AWS region hosting the private-mode VPC."
  type        = string
  default     = "eu-central-1"
}

variable "network_name" {
  description = "Name of the GCP VPC network."
  type        = string
}

variable "subnetwork_name" {
  description = "Name of the GCP subnetwork."
  type        = string
}

variable "gcp_subnet_cidr" {
  description = "Subnet CIDR range(s)."
  type        = list(string)
}

variable "gcp_vpc_cidr" {
  description = "VPC CIDR range(s), announced across the tunnel in private mode."
  type        = list(string)
}

variable "databricks_vpc_cidr" {
  description = "AWS Databricks VPC CIDR, allowed through the GCP firewall."
  type        = string
}

variable "databricks_subnets" {
  description = "Subnets of the private-mode AWS VPC."
  type        = map(string)
  default     = {}
}

variable "vpn_gw_name" {
  description = "Name of the HA VPN gateway (private mode only)."
  type        = string
  default     = "gcp-to-aws-ha-vpn"
}

variable "is_private_connection" {
  description = "Private mode builds the cross-cloud VPN: the GCP HA VPN gateway, the private DNS zone, and the whole AWS-side VPC (NAT gateway included)."
  type        = bool
  default     = false
}

variable "provider_key" {
  description = "Seed service-account key, consumed by the generated provider block."
  type        = string
  sensitive   = true
  default     = null
}
