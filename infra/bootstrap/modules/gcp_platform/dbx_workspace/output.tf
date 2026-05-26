output "gcp_serverless_workspace_id" {
  value       = databricks_mws_workspaces.this.workspace_id
  description = "The unique identifier of the created Databricks workspace"
}

output "gcp_serverless_workspace_url" {
  value       = databricks_mws_workspaces.this.workspace_url
  description = "The URL of the created Databricks workspace"
}