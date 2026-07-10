# --- Network Identifiers ---

output "gcp_vpc_id" {
  description = "The ID of the GCP VPC network."
  value       = google_compute_network.gcp_vpc.id
}

output "gcp_vpc_name" {
  description = "The name of the GCP VPC network."
  value       = google_compute_network.gcp_vpc.name
}

output "gcp_subnet_id" {
  description = "The ID of the created subnet."
  value       = google_compute_subnetwork.gcp_subnet.id
}

# --- VPN Gateway Information (Critical for Integration) ---

output "gcp_vpn_gw_id" {
  description = "The ID of the HA VPN gateway."
  value       = one(google_compute_ha_vpn_gateway.gcp_vpn_gw[*].id)
}

output "gcp_vpn_gw_ips" {
  description = "The public IP addresses assigned to the GCP HA VPN gateway. Use these in AWS Customer Gateway."
  value       = try([for i in google_compute_ha_vpn_gateway.gcp_vpn_gw[0].vpn_interfaces : i.ip_address], [])
}