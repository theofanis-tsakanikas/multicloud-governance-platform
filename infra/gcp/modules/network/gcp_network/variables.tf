# --- Project & Region Configuration ---

variable "project_id" {
  description = "The ID of the GCP Project where network resources will be created."
  type        = string
}

variable "location" {
  description = "The GCP region for the subnetwork and VPN (e.g., europe-west3)."
  type        = string
}

# --- VPC & Subnet Configuration ---

variable "network_name" {
  description = "The name of the VPC network."
  type        = string
}

variable "subnetwork_name" {
  description = "The name of the regional subnetwork."
  type        = string
}

variable "gcp_subnet_cidr" {
  description = "The CIDR range for the GCP subnetwork (e.g., 10.30.1.0/24)."
  type        = string
}

# --- Connectivity & Firewall ---

variable "databricks_vpc_cidr" {
  description = "The CIDR block of the AWS Databricks VPC for firewall whitelisting (e.g., 10.10.0.0/16)."
  type        = string
}

variable "vpn_gw_name" {
  description = "The name of the HA VPN Gateway."
  type        = string
}

variable "is_private_connection" {
  description = "Private mode adds the HA VPN gateway to AWS and the private DNS zone for restricted googleapis. The VPC, subnet and firewall are free and are created either way."
  type        = bool
  default     = false
}

variable "private_api_vip_cidr" {
  description = "private.googleapis.com VIP range (199.36.153.8/30). A route sends it to Google's private API frontend; without it, traffic arriving over the VPN is dropped."
  type        = string
  default     = "199.36.153.8/30"
}
