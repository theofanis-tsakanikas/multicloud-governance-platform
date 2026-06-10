# Virtual Network
# The core network container for all Azure resources
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.azure_vnet_cidr
  location            = var.location
  resource_group_name = var.resource_group_name
}



# Subnet for Data
# Dedicated space for storage and data-processing resources
resource "azurerm_subnet" "data_subnet" {
  name                 = "snet-data"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.data_subnet_prefix
}

# Subnet for Private Endpoints
# Specifically hardened for Private Link interfaces
resource "azurerm_subnet" "endpoint_subnet" {
  name                 = "snet-endpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.endpoint_subnet_prefix

  # Mandatory setting for Private Endpoints to function correctly
  private_endpoint_network_policies = "Enabled"
}

# GatewaySubnet for VPN
# Reserved name required by Azure for the Virtual Network Gateway
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet" # This name is reserved; do not change!
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.gateway_subnet_prefix
}

# Network Security Group (NSG) for SQL
# Firewall rules to protect the SQL Server Private Endpoint
resource "azurerm_network_security_group" "sql_nsg" {
  name                = "nsg-mssql-private"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                   = "AllowSQLInbound"
    priority               = 100
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "1433"

    # Merges AWS Databricks VPC and local VNet CIDRs to allow cross-cloud traffic
    source_address_prefixes = flatten([
      [var.databricks_vpc_cidr],
      var.azure_vnet_cidr
    ])
    destination_address_prefix = "*"
  }
}

# Associating the NSG with the Endpoint Subnet
resource "azurerm_subnet_network_security_group_association" "endpoint_nsg_assoc" {
  subnet_id                 = azurerm_subnet.endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.sql_nsg.id
}

# Public IP for the VPN Gateway
resource "azurerm_public_ip" "vpn_gw_pip" {
  name                = "pip-vpn-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# The Virtual Network Gateway
# The "engine" that handles the Site-to-Site VPN tunnel to AWS
resource "azurerm_virtual_network_gateway" "vpn_gw" {
  name                = "vgw-azure-to-aws"
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw1" # Enterprise-ready performance tier

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_pip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }

  # Ensure all subnets and security rules are ready before creating the gateway
  depends_on = [
    azurerm_subnet.endpoint_subnet,
    azurerm_subnet.data_subnet,
    azurerm_subnet_network_security_group_association.endpoint_nsg_assoc
  ]
}
