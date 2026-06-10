output "az_spn_client_id" {
  description = "The Client ID (Application ID) of the Service Principal."
  value       = msgraph_resource.databricks_app.output.client_id_export
}
output "databricks_application_id" {
  description = "The id of the application for the databricks connection"
  value       = msgraph_resource.databricks_app.output.object_id_export
}
