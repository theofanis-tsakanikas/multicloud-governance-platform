output "vpn_tunnel_name" {
  description = "The GCP VPN tunnel to AWS; empty in public mode, where this layer builds nothing."
  value       = try(module.vpn_bridge["enabled"].gcp_vpn_tunnel_name, "")
}

output "bq_endpoint_service_name" {
  description = "The PrivateLink service fronting the BigQuery gateway — what the NCC rule points at. Empty in public mode."
  value       = try(module.bq_gateway["enabled"].endpoint_service_name, "")
}
