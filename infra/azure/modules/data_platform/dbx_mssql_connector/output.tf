output "connection_id" {
  value       = module.azure_sql_databricks_connection.connection_id
  description = "The unique ID of the Databricks connection."
}

output "connection_name" {
  value       = module.azure_sql_databricks_connection.connection_name
  description = "The name of the external connection to Azure SQL."
}

/*
output "secret_scope_name" {
  value       = module.azure_sql_databricks_connection.secret_scope_name
  description = "The name of the Databricks secret scope."
}
*/