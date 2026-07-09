output "connection_name" {
  value       = databricks_connection.rds_postgres.name
  description = "The Unity Catalog connection name the federated catalog (sales_rds_fed) binds to."
}
