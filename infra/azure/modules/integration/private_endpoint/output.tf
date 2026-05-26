output "private_endpoint_id" {
  description = "The unique identifier of the created Private Endpoint"
  value       = azurerm_private_endpoint.sql_endpoint.id
}

output "private_ip_address" {
  description = "The internal private IP address assigned to the SQL Server within the VNet"
  value       = azurerm_private_endpoint.sql_endpoint.private_service_connection[0].private_ip_address
}

output "dns_zone_id" {
  description = "The resource ID of the Private DNS Zone used for SQL name resolution"
  value       = azurerm_private_dns_zone.sql_zone.id
}