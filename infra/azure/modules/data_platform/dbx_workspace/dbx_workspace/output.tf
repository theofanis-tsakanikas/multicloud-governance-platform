output "managed_workspace_url" {
  description = "The login URL of the newly created Databricks Workspace."
  value       = databricks_mws_workspaces.this.workspace_url
}

output "managed_workspace_id" {
  description = "The unique ID of the Databricks Workspace."
  value       = databricks_mws_workspaces.this.workspace_id
}

output "managed_workspace_status" {
  description = "The current status of the workspace (e.g., RUNNING)."
  value       = databricks_mws_workspaces.this.workspace_status
}

output "storage_configuration_id" {
  description = "The ID of the Databricks storage configuration."
  value       = databricks_mws_storage_configurations.this.storage_configuration_id
}

output "network_id" {
  description = "The ID of the Databricks network configuration."
  value       = databricks_mws_networks.this.network_id
}

output "managed_workspace_bucket_name" {
  value = aws_s3_bucket.root_storage.bucket
}