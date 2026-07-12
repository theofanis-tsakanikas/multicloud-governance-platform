output "catalog_name" {
  description = "The FEDERATED BigQuery catalog in the AWS serverless workspace."
  value       = databricks_catalog.marketing_bq_fed.name
}

output "connection_name" {
  value = databricks_connection.bigquery.name
}
