output "connection_id" {
  value       = databricks_connection.azure_sql.id
  description = "The Unity Catalog connection id."
}

output "connection_name" {
  value       = databricks_connection.azure_sql.name
  description = "The UC connection name the federated catalog (supply_sql_master) binds to."
}
