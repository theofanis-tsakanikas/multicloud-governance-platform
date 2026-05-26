output "spn_application_id" {
  description = "The Client ID of the created Service Principal"
  value       = databricks_service_principal.automation_sp.application_id
}

output "spn_id" {
  description = "The Databricks internal ID of the Service Principal"
  value       = databricks_service_principal.automation_sp.id
}

output "admin_group_id" {
  description = "The ID of the created Admin Group"
  value       = databricks_group.admins.id
}

output "admin_group_name" {
  description = "The display name of the Admin Group"
  value       = databricks_group.admins.display_name
}

output "functional_group_ids" {
  description = "Map of functional group names to their Databricks IDs"
  value       = { for k, v in databricks_group.functional_groups : k => v.id }
}