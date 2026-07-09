output "connection_id" {
  value       = databricks_connection.bigquery.id
  description = "The Unity Catalog connection id."
}

output "connection_name" {
  value       = databricks_connection.bigquery.name
  description = "The UC connection name the federated catalog (marketing_bq_fed) binds to."
}
