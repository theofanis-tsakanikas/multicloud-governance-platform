# Resource to register a specific path in storage as a Unity Catalog External Location
resource "databricks_external_location" "location" {
  name = var.location_name
  # The URL format must be e.g. for Azure abfss://container@storage_account.dfs.core.windows.net/
  # This uses the Azure Blob File System (ABFSS) driver for ADLS Gen2
  url = var.calculated_url

  # References the Storage Credential (the IAM/Service Principal link) created in Step 2
  credential_name = var.storage_credential_name

  comment = "External location for Azure ADLS Gen2 data federation"

  # Ensures that if the resource is deleted via Terraform, dependent objects are also handled
  force_destroy = true

  lifecycle {
    create_before_destroy = false
  }
}

# Resource to manage granular access control for the External Location
resource "databricks_grants" "some" {
  external_location = databricks_external_location.location.id

  # Dynamic block to apply multiple permissions from a JSON/Variable input
  dynamic "grant" {
    # Flattening the nested JSON structure: [ { grants: [ {principal, privileges} ] } ]
    # This allows a single resource to manage all users (Principals) and their rights (Privileges)
    for_each = flatten([
      for loc in var.external_location_grants : [
        for g in loc.grants : g
      ]
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
}