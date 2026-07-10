output "private_endpoint_ip" {
  description = "Private IP the SQL server resolves to inside the VNet; null in public mode."
  value       = try(module.private_endpoint["enabled"].private_ip_address, null)
}

output "vpn_connection_id" {
  description = "AWS side of the Site-to-Site VPN; null in public mode."
  value       = try(module.aws_az_vpn_conn["enabled"].vpn_connection_id, null)
}
