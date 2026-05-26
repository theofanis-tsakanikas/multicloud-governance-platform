output "serverless_workspace_id" {
  value = databricks_mws_workspaces.this.workspace_id
}

output "serverless_workspace_url" {
  value = databricks_mws_workspaces.this.workspace_url
}

output "ncc_id" {
  value = databricks_mws_network_connectivity_config.ncc.network_connectivity_config_id
}