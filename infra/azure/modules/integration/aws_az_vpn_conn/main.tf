# AWS SIDE: Declaring Azure as a "Customer"
resource "aws_customer_gateway" "azure_side" {
  bgp_asn    = 65000
  ip_address = var.azure_vpn_public_ip # Public IP retrieved from azurerm_public_ip
  type       = "ipsec.1"

  tags = { Name = "customer-gw-to-azure" }
}

# AWS SIDE: Creating the VPN Tunnel
resource "aws_vpn_connection" "aws_to_azure" {
  vpn_gateway_id      = var.aws_vpn_gw_id
  customer_gateway_id = aws_customer_gateway.azure_side.id
  type                = "ipsec.1"
  static_routes_only  = true

  # The pre-shared key (secret password) for the tunnel
  tunnel1_preshared_key = var.shared_key

  tags = { Name = "s2s-connection-to-azure" }
}

# Registering the Static Route within the VPN connection
resource "aws_vpn_connection_route" "azure_static_route" {
  for_each = toset(var.azure_vnet_cidr)

  destination_cidr_block = each.value
  vpn_connection_id      = aws_vpn_connection.aws_to_azure.id
}

# AWS Private DNS Bridge (Route 53)
# Creating the database.windows.net zone inside the AWS VPC
resource "aws_route53_zone" "azure_dns_proxy" {
  name = "database.windows.net"

  vpc {
    vpc_id = var.vpc_id # Ensure this variable is defined in your module
  }

  tags = { Name = "azure-sql-dns-proxy" }
}

# DNS record linking the Hostname to the Private IP
resource "aws_route53_record" "sql_server_record" {
  zone_id = aws_route53_zone.azure_dns_proxy.zone_id

  # Extracts the short hostname (e.g., "sql-federation-master") from the FQDN
  name = split(".", var.sql_server_fqdn)[0]

  type    = "A"
  ttl     = "300"
  records = [var.private_ip_address]
}

# AZURE SIDE: Declaring AWS as a "Local Network"
resource "azurerm_local_network_gateway" "aws_side" {
  name                = "lgw-aws-side"
  location            = var.location
  resource_group_name = var.resource_group_name

  gateway_address = aws_vpn_connection.aws_to_azure.tunnel1_address # AWS Tunnel Public IP
  address_space   = [var.databricks_vpc_cidr]                       # The AWS network range reachable from Azure
}

# AZURE SIDE: The Final Connection (Activation)
resource "azurerm_virtual_network_gateway_connection" "azure_to_aws" {
  name                = "conn-azure-to-aws"
  location            = var.location
  resource_group_name = var.resource_group_name

  type                       = "IPsec"
  virtual_network_gateway_id = var.azure_vpn_gw_id
  local_network_gateway_id   = azurerm_local_network_gateway.aws_side.id
  shared_key                 = var.shared_key # Must match AWS tunnel1_preshared_key
}