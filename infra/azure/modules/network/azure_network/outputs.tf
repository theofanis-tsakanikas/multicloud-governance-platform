output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "data_subnet_id" {
  value = azurerm_subnet.data_subnet.id
}

output "endpoint_subnet_id" {
  value = azurerm_subnet.endpoint_subnet.id
}

output "azure_vpn_public_ip" {
  description = "The Public IP address for the Azure VPN Gateway"
  value       = azurerm_public_ip.vpn_gw_pip.ip_address
}

output "azure_vpn_gw_id" {
  description = "The ID of the Azure Virtual Network Gateway"
  value       = azurerm_virtual_network_gateway.vpn_gw.id
}