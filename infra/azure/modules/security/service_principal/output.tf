output "spn_object_id" {
  description = "The Object ID of the Service Principal (used for role assignment)."
  value       = msgraph_resource.databricks_spn.output.spn_object_id
}