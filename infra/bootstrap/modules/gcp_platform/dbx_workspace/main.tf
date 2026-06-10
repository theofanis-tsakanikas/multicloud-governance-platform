# 1. Workspace Creation (GCP Version)
resource "databricks_mws_workspaces" "this" {
  account_id     = var.dbx_account_id
  workspace_name = "${var.workspace_name}-${var.environment}"
  location       = var.location # e.g., "europe-west3"

  # SERVERLESS mode is recommended for faster startup and reduced infrastructure overhead
  compute_mode = "SERVERLESS"

  # MANDATORY: Tells Databricks which GCP Project owns this workspace resource
  cloud_resource_container {
    gcp {
      project_id = var.project_id
    }
  }

  pricing_tier = var.workspace_pricing_tier
}

# 2. Metastore Assignment
# Links the newly created workspace to the global Unity Catalog Metastore
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.gcp_metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}

# 3. Permission Assignments
# Grants the Admin Group full administrative rights over the workspace
resource "databricks_mws_permission_assignment" "workspace_admin_assignment" {
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.admin_group_id
  permissions  = ["ADMIN"]

  depends_on = [databricks_metastore_assignment.this]
}

# Grants standard USER access to all functional groups (Data Science, Engineering, etc.)
resource "databricks_mws_permission_assignment" "all_groups_assignment" {
  for_each     = var.functional_group_ids
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = each.value
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.this]
}

# 4. Identity Sync Wait
# Essential pause to allow the Databricks account-level identities to propagate to the workspace
resource "time_sleep" "wait_for_identity_sync" {
  depends_on = [
    databricks_mws_permission_assignment.workspace_admin_assignment,
    databricks_mws_permission_assignment.all_groups_assignment
  ]
  create_duration = "60s"
}