output "external_location_id" {
  value       = databricks_external_location.location.id
  description = "The ID of the external location to force dependency"
}