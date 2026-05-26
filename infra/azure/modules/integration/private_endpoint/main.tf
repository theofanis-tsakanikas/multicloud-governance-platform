# 1. Create Private DNS Zone for Azure SQL
# This zone handles the internal name resolution for SQL Private Link
resource "azurerm_private_dns_zone" "sql_zone" {
  name                = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
}

# 2. Link the DNS Zone to our Virtual Network (VNet)
# This allows resources within the VNet to use this private zone
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "sql-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sql_zone.name
  virtual_network_id    = var.vnet_id
}

# 3. Create the Private Endpoint
# This generates a network interface (NIC) in your subnet with a private IP for SQL access
resource "azurerm_private_endpoint" "sql_endpoint" {
  name                = "${var.sql_server_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.endpoint_subnet_id

  private_service_connection {
    name                           = "sql-privatelink"
    private_connection_resource_id = var.sql_server_id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  # Automatically registers the Private Endpoint's IP in the DNS Zone
  private_dns_zone_group {
    name                 = "sql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_zone.id]
  }
}