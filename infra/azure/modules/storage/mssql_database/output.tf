output "sql_server_fqdn" {
  value       = azurerm_mssql_server.example.fully_qualified_domain_name
  description = "The fully qualified domain name (FQDN) of the SQL Server (e.g., xxxx.database.windows.net)."
}

output "sql_database_name" {
  value       = azurerm_mssql_database.example.name
  description = "The name of the SQL Database."
}

output "sql_server_id" {
  value       = azurerm_mssql_server.example.id
  description = "The Resource ID of the SQL Server."
}

output "sql_server_name" {
  value = azurerm_mssql_server.example.name
}

output "database_id" {
  value = azurerm_mssql_database.example.id
}

output "aws_frankfurt_ips" {
  value = data.aws_ip_ranges.frankfurt_ec2.cidr_blocks
}
