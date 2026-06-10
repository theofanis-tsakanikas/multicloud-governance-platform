locals {
  # Parses the JSON map provided by the Python orchestrator containing share definitions
  shares = jsondecode(var.delta_shares_map_json)
}

# Creates a Delta Share for each catalog/group identified by the orchestrator
resource "databricks_share" "this" {
  for_each = local.shares
  name     = each.value.share_name

  # Dynamically adds tables or volumes to the share based on the JSON input
  dynamic "object" {
    for_each = each.value.objects
    content {
      # The full three-level name (catalog.schema.table)
      name = object.value.full_name
      # Supports both 'TABLE' and 'VOLUME' types
      data_object_type = object.value.type
      # Volume sharing requires history data sharing to be enabled
      history_data_sharing_status = object.value.type == "VOLUME" ? "ENABLED" : null
    }
  }
}

# Defines the external Databricks workspace (AWS side) as a Recipient
resource "databricks_recipient" "aws_side" {
  name = var.aws_db_recipient
  # 'DATABRICKS' type allows for seamless sharing between Databricks accounts
  authentication_type = "DATABRICKS"
  # The unique global ID of the target AWS Metastore
  data_recipient_global_metastore_id = var.aws_global_metastore_id
}



# Grants the Recipient 'SELECT' privileges for EVERY share created above
resource "databricks_grants" "some" {
  for_each = databricks_share.this
  share    = each.value.name
  grant {
    principal = databricks_recipient.aws_side.name
    # 'SELECT' is the required privilege for a recipient to access shared data
    privileges = ["SELECT"]
  }
}