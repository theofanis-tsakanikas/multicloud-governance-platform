# --- AWS Connectivity Variables ---

variable "aws_vpn_gw_id" {
  description = "The ID of the AWS Virtual Private Gateway (VGW)."
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
variable "private_api_vip_cidr" {
  description = "private.googleapis.com VIP range. The Cloud Router must ADVERTISE this to AWS: a static route only gets the packet to the VGW, which then forwards on BGP-learned prefixes alone. Without the advertisement the VGW has no route for the VIP and drops it — silently, with every tunnel and route showing green."
  type        = string
  default     = "199.36.153.8/30"
}
