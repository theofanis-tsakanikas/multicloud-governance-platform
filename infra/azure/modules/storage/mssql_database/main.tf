# Fetches all available EC2 IP ranges for the provider's defined region
# Databricks Compute runs on EC2 nodes, so these IPs are needed for whitelisting
data "aws_ip_ranges" "frankfurt_ec2" {
  regions  = [var.region]
  services = ["ec2"]
}

locals {
  # If the connection is private, the list remains empty (handled by Private Link/VPN)
  # If public, we combine your Orchestrator IP with the regional AWS EC2 CIDR blocks
  all_firewall_cidrs = var.is_private_connection ? [] : concat(
    var.orch_ip,
    data.aws_ip_ranges.frankfurt_ec2.cidr_blocks
  )
}

# Generates a strong, random password for the SQL Admin
resource "random_password" "sql_admin" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Creates a unique suffix to ensure the SQL Server name is globally unique
resource "random_id" "suffix" {
  byte_length = 4
}

# The Azure SQL Logical Server resource
resource "azurerm_mssql_server" "example" {
  name                         = "${var.sql_server_name}-${random_id.suffix.hex}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_user
  administrator_login_password = random_password.sql_admin.result
  minimum_tls_version          = "1.2"
  # Disables public access if a private connection (VPN) is established
  public_network_access_enabled = var.is_private_connection ? false : true
  connection_policy             = "Proxy"
}



# Securely stores the generated SQL Admin password in Azure Key Vault
resource "azurerm_key_vault_secret" "sql_password" {
  name         = var.sql_password_name
  value        = random_password.sql_admin.result
  key_vault_id = var.key_vault_id
}

# The SQL Database using the Serverless compute tier
resource "azurerm_mssql_database" "example" {
  name      = var.sql_database_name
  server_id = azurerm_mssql_server.example.id
  collation = "SQL_Latin1_General_CP1_CI_AS"
  # GP_S_Gen5_1: The 'S' denotes the Serverless tier
  sku_name    = "GP_S_Gen5_1"
  max_size_gb = 2

  # Serverless specific settings (Auto-pause helps minimize costs)
  min_capacity                = 0.5
  auto_pause_delay_in_minutes = 60 # Shuts down after 1 hour of inactivity
}

# Dynamic creation of firewall rules based on the CIDR list in locals
resource "azurerm_mssql_firewall_rule" "sql_firewall_rules" {
  for_each = toset(local.all_firewall_cidrs)

  name      = "Allow-${replace(each.value, "/", "-")}"
  server_id = azurerm_mssql_server.example.id

  # Calculates Start and End IPs from the CIDR block for Azure's firewall format
  start_ip_address = cidrhost(each.value, 0)
  end_ip_address   = cidrhost(each.value, pow(2, 32 - tonumber(split("/", each.value)[1])) - 1)
}