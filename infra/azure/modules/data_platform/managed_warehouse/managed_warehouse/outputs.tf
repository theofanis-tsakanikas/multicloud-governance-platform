output "warehouse_id" {
  description = "Id of the created SQL warehouse."
  value       = databricks_sql_endpoint.managed.id
}
