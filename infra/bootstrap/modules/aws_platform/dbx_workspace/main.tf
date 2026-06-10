# 1. Workspace Creation
resource "databricks_mws_workspaces" "this" {
  account_id     = var.dbx_account_id
  aws_region     = var.region
  workspace_name = "${var.workspace_name}-${var.environment}"

  # For Serverless/Managed Workspaces, these are the core configurations
  pricing_tier = var.workspace_pricing_tier
  compute_mode = "SERVERLESS"
}

# Metastore Assignment
# Links the workspace to the global Unity Catalog Metastore
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}

# Permission Assignments
# Grants administrative rights to the designated Admin Group
resource "databricks_mws_permission_assignment" "workspace_admin_assignment" {
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.admin_group_id
  permissions  = ["ADMIN"]

  depends_on = [databricks_metastore_assignment.this]
}

# Grants standard USER access to all functional groups
resource "databricks_mws_permission_assignment" "all_groups_assignment" {
  for_each     = var.functional_group_ids
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = each.value
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.this]
}

# Identity Sync Wait
# Essential pause to allow account-level identities to propagate to the workspace
resource "time_sleep" "wait_for_identity_sync" {
  depends_on = [
    databricks_mws_permission_assignment.workspace_admin_assignment,
    databricks_mws_permission_assignment.all_groups_assignment
  ]
  create_duration = "60s"
}

# 2. Network Connectivity Config (NCC)
# Mandatory for Serverless Compute to communicate with AWS resources (e.g., S3 via PrivateLink)
resource "databricks_mws_network_connectivity_config" "ncc" {
  account_id = var.dbx_account_id
  name       = "ncc-${var.workspace_name}-${var.environment}"
  region     = var.region
}



resource "time_sleep" "wait_30_seconds" {
  depends_on = [databricks_mws_network_connectivity_config.ncc]

  # During destroy, wait 30 seconds after the binding is removed to ensure clean teardown
  destroy_duration = "30s"
}

# 3. Binding: Connecting the NCC to the Workspace
resource "databricks_mws_ncc_binding" "this" {
  network_connectivity_config_id = databricks_mws_network_connectivity_config.ncc.network_connectivity_config_id
  workspace_id                   = databricks_mws_workspaces.this.workspace_id
  depends_on                     = [time_sleep.wait_30_seconds]
}