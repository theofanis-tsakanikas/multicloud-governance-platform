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

# ── The subnet nothing lives in, and why it still gets a firewall ────────────────────────────────
#
# Checkov CKV2_AZURE_31 flagged `snet-data` as the one subnet in this VNet with no NSG attached, and
# it was right — the first time that scan was ever allowed to run. (`GatewaySubnet` passes because
# Azure forbids an NSG on it; `snet-endpoints` has the SQL one above.)
#
# Nothing is deployed into snet-data today. Its id is exported and nothing consumes it. Which is
# exactly the argument for closing it rather than skipping the check: an empty subnet with no NSG is
# not safe, it is *unclaimed* — and the day somebody puts a VM or a container in it, the absence is
# already there and nobody is looking any more.
#
# It carries no custom rules on purpose. Azure's own default rules deny all inbound from the internet
# (DenyAllInBound, priority 65500) and allow traffic within the VNet, which is precisely the posture
# a data subnet should start from: nothing gets in until someone writes down why.
resource "azurerm_network_security_group" "data_nsg" {
  name                = "nsg-data-default-deny"
  location            = var.location
  resource_group_name = var.resource_group_name

  # No security_rule blocks. The default DenyAllInBound is the rule.
}

resource "azurerm_subnet_network_security_group_association" "data_nsg_assoc" {
  subnet_id                 = azurerm_subnet.data_subnet.id
  network_security_group_id = azurerm_network_security_group.data_nsg.id
}

# Public IP for the VPN Gateway — private mode only.
resource "azurerm_public_ip" "vpn_gw_pip" {
  count = var.is_private_connection ? 1 : 0

  name                = "pip-vpn-gateway"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  # VpnGw1AZ is zone-redundant, and Azure requires its public IP to be zone-redundant too:
  # "Standard Public IPs associated with VPN Gateways with AZ VPN skus must have zones configured."
  zones = ["1", "2", "3"]
}

# The Virtual Network Gateway
# The "engine" that handles the Site-to-Site VPN tunnel to AWS
# The Virtual Network Gateway is the single most expensive resource in the Azure
# stack (VpnGw1, ~EUR 140/month, billed whether or not a tunnel is up). It exists
# only to carry the Site-to-Site VPN to AWS, which only private mode needs.
resource "azurerm_virtual_network_gateway" "vpn_gw" {
  count = var.is_private_connection ? 1 : 0

  name                = "vgw-azure-to-aws"
  location            = var.location
  resource_group_name = var.resource_group_name

  type     = "Vpn"
  vpn_type = "RouteBased"
  # Azure retired the non-AZ VpnGw1-5 SKUs: "NonAzSkusNotAllowedForVPNGateway ... Only VpnGw1-5AZ
  # SKUs can be created going forward." VpnGw1AZ is the zone-redundant equivalent — same tier,
  # same ~EUR 140/month, and it pairs with the Standard (zone-redundant) public IP above.
  sku = "VpnGw1AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gw_pip[0].id
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
