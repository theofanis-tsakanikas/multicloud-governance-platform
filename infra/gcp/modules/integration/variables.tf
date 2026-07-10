variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "location" {
  description = "GCP region."
  type        = string
}

variable "is_private_connection" {
  description = "When false this layer is a no-op: no VPN, no DNS bridge."
  type        = bool
  default     = false
}

variable "gcs_bucket_name" {
  description = "Bucket from the foundation layer (kept for parity; unused in public mode)."
  type        = string
  default     = null
}

variable "network_name" {
  description = "GCP VPC name."
  type        = string
  default     = null
}

variable "subnetwork_name" {
  description = "GCP subnetwork name."
  type        = string
  default     = null
}

# ── Private mode only. ────────────────────────────────────────────────────────
variable "databricks_vpc_id" {
  description = "AWS VPC id of the Databricks workspace (private mode only)."
  type        = string
  default     = null
}

variable "aws_vpn_gw_id" {
  description = "AWS VPN gateway id (private mode only)."
  type        = string
  default     = null
}

variable "gcp_vpc_id" {
  description = "GCP VPC id (private mode only)."
  type        = string
  default     = null
}

variable "gcp_vpn_gw_id" {
  description = "GCP HA VPN gateway id (private mode only)."
  type        = string
  default     = null
}

variable "gcp_vpn_gw_ips" {
  description = "GCP HA VPN gateway interface IPs (private mode only)."
  type        = list(string)
  default     = []
}

variable "provider_key" {
  description = "Seed service-account key, consumed by the generated provider block."
  type        = string
  sensitive   = true
  default     = null
}
