output "gcp_vpc_id" {
  description = "GCP VPC id."
  value       = module.gcp_network.gcp_vpc_id
}

output "gcp_vpc_name" {
  description = "GCP VPC name."
  value       = module.gcp_network.gcp_vpc_name
}

output "gcp_subnet_id" {
  description = "GCP subnet id."
  value       = module.gcp_network.gcp_subnet_id
}

output "gcp_vpn_gw_id" {
  description = "GCP HA VPN gateway id; null in public mode."
  value       = module.gcp_network.gcp_vpn_gw_id
}

output "gcp_vpn_gw_ips" {
  description = "GCP HA VPN gateway interface IPs; empty in public mode."
  value       = module.gcp_network.gcp_vpn_gw_ips
}

# AWS side — private mode only.
output "vpc_id" {
  description = "AWS VPC id; null in public mode."
  value       = try(module.aws_network["enabled"].vpc_id, null)
}

output "private_subnet_ids" {
  description = "AWS private subnet ids; null in public mode."
  value       = try(module.aws_network["enabled"].private_subnet_ids, null)
}

output "security_group_id" {
  description = "AWS security group id; null in public mode."
  value       = try(module.aws_network["enabled"].security_group_id, null)
}

output "aws_vpn_gw_id" {
  description = "AWS VPN gateway id; null in public mode."
  value       = try(module.aws_network["enabled"].aws_vpn_gw_id, null)
}
