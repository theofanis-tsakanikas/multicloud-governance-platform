# Use the catalog name from the JSON to apply specific grants
resource "databricks_grants" "federated_schema_grants" {
  # Iterates through the schemas defined in the federated_catalog object
  for_each = { for s in var.federated_catalog.schemas : s.schema_name => s }

  # Target format: <catalog_name>.<schema_name>
  schema = "${var.federated_catalog.catalog_name}.${each.key}"

  # Dynamic block to inject multiple privileges from the provided grant list
  dynamic "grant" {
    # Filters the global federated_schema_grants list to match the current schema context
    for_each = flatten([
      for sg in var.federated_schema_grants : [
        for g in sg.grants : g
      ] if sg.schema == "${var.federated_catalog.catalog_name}.${each.key}"
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
}