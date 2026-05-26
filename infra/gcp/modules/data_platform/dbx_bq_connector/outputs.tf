output "connection_id" {
  description = "The unique ID of the Databricks connection."
  value       = module.dbx_bq_connector.connection_id
}

output "connection_name" {
  description = "The name of the Databricks connection."
  value       = module.dbx_bq_connector.connection_name
}

