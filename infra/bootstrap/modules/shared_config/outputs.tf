output "warehouse_id" {
  description = "The ID of the SQL Warehouse"
  value       = databricks_sql_endpoint.serverless_starter.id
}

output "warehouse_data_source_id" {
  description = "The Data Source ID (needed for some API integrations)"
  value       = databricks_sql_endpoint.serverless_starter.data_source_id
}

output "warehouse_http_path" {
  description = "The HTTP path for JDBC/ODBC connections"
  value       = databricks_sql_endpoint.serverless_starter.jdbc_url
}

output "warehouse_name" {
  description = "The display name of the SQL Warehouse"
  value       = databricks_sql_endpoint.serverless_starter.name
}