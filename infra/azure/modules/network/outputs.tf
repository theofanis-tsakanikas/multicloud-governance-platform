# Terraform omits an output whose value is null from the state entirely, so a
# downstream `dependency.network.outputs.vpc_id` fails with "Unsupported
# attribute" rather than reading a null. Public mode therefore yields "" —
# present, and obviously empty.

# Azure side — always present.
output "vnet_id" {
  description = "VNet id; the private endpoint links into it."
  value       = module.azure_network.vnet_id
}

output "endpoint_subnet_id" {
  description = "Subnet the SQL private endpoint lands in."
  value       = module.azure_network.endpoint_subnet_id
}

output "data_subnet_id" {
  description = "Data subnet id."
  value       = module.azure_network.data_subnet_id
}

output "azure_vpn_public_ip" {
  description = "Azure VPN gateway public IP; null in public mode."
  value       = module.azure_network.azure_vpn_public_ip == null ? "" : module.azure_network.azure_vpn_public_ip
}

output "azure_vpn_gw_id" {
  description = "Azure VPN gateway id; null in public mode."
  value       = module.azure_network.azure_vpn_gw_id == null ? "" : module.azure_network.azure_vpn_gw_id
}

# AWS side — private mode only. Null in public mode, where the platform uses the
# serverless workspace created during bootstrap and needs no VPC of its own.
output "vpc_id" {
  description = "AWS VPC id; null in public mode."
  value       = try(module.aws_network["enabled"].vpc_id, "")
}

output "private_subnet_ids" {
  description = "AWS private subnet ids; null in public mode."
  value       = try(module.aws_network["enabled"].private_subnet_ids, [])
}

output "security_group_id" {
  description = "AWS security group id; null in public mode."
  value       = try(module.aws_network["enabled"].security_group_id, "")
}

output "aws_vpn_gw_id" {
  description = "AWS VPN gateway id; null in public mode."
  value       = try(module.aws_network["enabled"].aws_vpn_gw_id, "")
}
