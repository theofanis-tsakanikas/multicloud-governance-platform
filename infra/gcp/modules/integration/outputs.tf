output "vpn_tunnel_names" {
  description = "GCP VPN tunnels; empty in public mode."
  value       = try(module.vpn_bridge["enabled"].gcp_vpn_tunnel_names, [])
}

output "route53_zone_id" {
  description = "Route53 private zone bridging googleapis DNS; null in public mode."
  value       = try(module.dns_bridge["enabled"].route53_zone_id, null)
}
