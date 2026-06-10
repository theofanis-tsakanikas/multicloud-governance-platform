output "managed_workspace_url" {
  description = "The login URL of the newly created Databricks Workspace."
  # Empty string when the private workspace is disabled (is_private_connection = false).
  value = var.is_private_connection ? module.dbx_workspace["enabled"].managed_workspace_url : ""
}

output "managed_workspace_id" {
  description = "The unique ID of the Databricks Workspace."
  value       = var.is_private_connection ? module.dbx_workspace["enabled"].managed_workspace_id : ""
}

output "managed_workspace_status" {
  description = "The current status of the workspace (e.g., RUNNING)."
  value       = var.is_private_connection ? module.dbx_workspace["enabled"].managed_workspace_status : ""
}

output "storage_configuration_id" {
  description = "The ID of the Databricks storage configuration."
  value       = var.is_private_connection ? module.dbx_workspace["enabled"].storage_configuration_id : ""
}

output "network_id" {
  description = "The ID of the Databricks network configuration."
  value       = var.is_private_connection ? module.dbx_workspace["enabled"].network_id : ""
}

output "managed_workspace_bucket_name" {
  description = "The S3 bucket name used for the root storage."
  value       = var.is_private_connection ? module.dbx_workspace["enabled"].managed_workspace_bucket_name : ""
}