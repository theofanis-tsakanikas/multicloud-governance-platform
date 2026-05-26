# --- AWS Connectivity Variables ---

variable "aws_vpn_gw_id" {
  description = "The ID of the AWS Virtual Private Gateway (VGW)."
  type        = string
}

variable "databricks_vpc_id" {
  description = "The ID of the AWS VPC where Databricks resides."
  type        = string
}

# --- GCP Connectivity Variables --- 

variable "gcp_vpc_id" {
  description = "The ID of the GCP VPC Network."
  type        = string
}

variable "gcp_vpn_gw_id" {
  description = "The ID of the GCP HA VPN Gateway."
  type        = string
}

variable "gcp_vpn_gw_ips" {
  description = "List of Public IPs from the GCP HA VPN Gateway (usually 2)."
  type        = list(string)
}

# --- Project Configuration ---

variable "location" {
  description = "The GCP region for the router and tunnels (e.g., europe-west3)."
  type        = string
}

variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}