output "aws_vpn_connection_id" {
  description = "The AWS VPN connection carrying the tunnel to GCP."
  value       = aws_vpn_connection.aws_to_gcp.id
}

output "gcp_vpn_tunnel_name" {
  description = "The single GCP tunnel. AWS reports its second tunnel DOWN by design — see main.tf."
  value       = google_compute_vpn_tunnel.tunnel.name
}

output "aws_tunnel_public_ip" {
  description = "The AWS endpoint the GCP tunnel dials."
  value       = aws_vpn_connection.aws_to_gcp.tunnel1_address
}

output "bgp_router_name" {
  description = "The Cloud Router holding the BGP session — GCP HA VPN has no static-route mode."
  value       = google_compute_router.gcp_router.name
}
