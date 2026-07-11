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
  description = "VPC CIDR range(s) the AWS side routes toward the tunnel: the GCP VPC, and Google's private API VIP."
  type        = list(string)
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

# ── The GCP transit hub (private mode only) ─────────────────────────────────────────────────────
variable "transit_vpc_cidr" {
  description = "GCP's own AWS transit VPC (10.11.0.0/16). NOT Azure's 10.10 — that hub is live."
  type        = string
  default     = "10.11.0.0/16"
}
variable "transit_subnets" {
  description = "Private subnets of the GCP transit VPC."
  type        = map(string)
  default     = {}
}
variable "transit_nat_cidr" {
  description = "NAT public subnet inside the transit VPC."
  type        = string
  default     = "10.11.100.0/24"
}
variable "ecr_repo_name" {
  description = "ECR repo for the bq-gateway image."
  type        = string
  default     = "bq-gateway"
}
variable "private_api_vip_cidr" {
  description = "private.googleapis.com VIP range; a route hands it to Google's private API frontend."
  type        = string
  default     = "199.36.153.8/30"
}
