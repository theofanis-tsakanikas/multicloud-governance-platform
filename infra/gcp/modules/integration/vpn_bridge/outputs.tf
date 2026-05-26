output "aws_vpn_connection_ids" {
  description = "The IDs of the AWS VPN connections."
  value       = aws_vpn_connection.aws_to_gcp[*].id
}

output "gcp_vpn_tunnel_names" {
  description = "The names of the GCP VPN tunnels created."
  value       = google_compute_vpn_tunnel.tunnels[*].name
}

output "aws_tunnel_public_ips" {
  description = "The Public IPs of the AWS VPN tunnels (to be whitelisted if needed)."
  value       = flatten([for conn in aws_vpn_connection.aws_to_gcp : [conn.tunnel1_address, conn.tunnel2_address]])
}

output "bgp_router_name" {
  description = "The name of the GCP Cloud Router."
  value       = google_compute_router.gcp_router.name
}
