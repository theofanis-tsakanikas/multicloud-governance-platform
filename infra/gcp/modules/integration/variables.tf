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

# ── The transit hub (private mode only) ─────────────────────────────────────────────────────────

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  description = "AWS region of the transit VPC — must match the Databricks serverless region."
  type        = string
  default     = "eu-central-1"
}

variable "transit_vpc_id" {
  description = "GCP's own AWS transit VPC (10.11.0.0/16), from the network layer."
  type        = string
  default     = ""
}

variable "transit_vpc_cidr" {
  description = "That VPC's CIDR. The gateway SG admits 443 from it — NLB health checks and PrivateLink traffic both arrive from inside the VPC."
  type        = string
  default     = "10.11.0.0/16"
}

variable "transit_subnet_ids" {
  description = "Private subnets of the transit VPC."
  type        = list(string)
  default     = []
}

variable "ecr_repo_name" {
  description = "ECR repo holding the bq-gateway image (created in the network layer)."
  type        = string
  default     = ""
}

variable "private_api_vip_ips" {
  description = "private.googleapis.com addresses (199.36.153.8-11). The gateway dials them by IP across the VPN."
  type        = list(string)
  default     = []
}

variable "google_api_domains" {
  description = "The Google API hosts the NCC rule routes privately. BigQuery federation needs all three: the query API, the Storage Read API the rows actually come from, and oauth2 — without which the service-account key cannot be exchanged for a token at all."
  type        = list(string)
  default     = ["bigquery.googleapis.com", "bigquerystorage.googleapis.com", "oauth2.googleapis.com"]
}

variable "ncc_id" {
  description = "Databricks Network Connectivity Config id (from bootstrap/aws/platform) — the same NCC the RDS and Azure SQL rules bind to."
  type        = string
  default     = ""
}

variable "databricks_serverless_privatelink_account_id" {
  description = "Databricks' serverless-PrivateLink AWS account — the only principal allowed into the endpoint service."
  type        = string
  default     = ""
}

variable "spn_client_id" {
  type    = string
  default = ""
}

variable "spn_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
