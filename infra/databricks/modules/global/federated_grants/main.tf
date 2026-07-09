# A FOREIGN catalog's schemas live in the remote engine, and Unity Catalog only
# materialises them once a compute resource queries the catalog. Applying grants
# before that fails with "Schema '<catalog>.<schema>' does not exist" — listing via
# the REST API does not trigger the discovery. This runs one `SHOW SCHEMAS` on the
# SQL warehouse and blocks until every declared schema is visible.
resource "terraform_data" "warm_foreign_catalog" {
  triggers_replace = [
    var.federated_catalog.catalog_name,
    join(",", [for s in var.federated_catalog.schemas : s.schema_name]),
  ]

  provisioner "local-exec" {
    command = "python3 ${path.module}/warm_foreign_catalog.py"
    environment = {
      DBX_HOST             = var.workspace_host
      DBX_CLIENT_ID        = var.spn_client_id
      DBX_CLIENT_SECRET    = var.spn_client_secret
      DBX_WAREHOUSE_ID     = var.warehouse_id
      DBX_CATALOG          = var.federated_catalog.catalog_name
      DBX_EXPECTED_SCHEMAS = join(",", [for s in var.federated_catalog.schemas : s.schema_name])
    }
  }
}

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

  depends_on = [terraform_data.warm_foreign_catalog]
}
