### 1. Catalog Creation
resource "databricks_catalog" "catalog" {
  name = var.catalog.catalog_name
  # For Federated: name of the databricks_connection
  connection_name = lookup(var.catalog, "connection_name", null)
  # If MANAGED, it takes storage_root. If FEDERATED, it's null.
  storage_root = var.catalog.calculated_storage_root

  # ISOLATED mode is only supported in MANAGED catalogs
  isolation_mode = var.catalog.type == "MANAGED" ? "ISOLATED" : null

  # Federated catalogs require the 'database' option to map the remote DB
  options = var.catalog.type == "FEDERATED" ? { "database" = lookup(var.catalog, "database_name", null) } : null

  comment       = "Catalog managed by Terraform"
  force_destroy = true
}

### 2. Catalog Grants
# Permissions applied at the Catalog level.
# var.catalog_grants is pre-filtered at the root module level.
resource "databricks_grants" "catalog_grants" {
  # Only creates the resource if the flattened list of grants has content
  count = length(flatten([
    for cg in var.catalog_grants : [for g in cg.grants : g]
  ])) > 0 ? 1 : 0

  catalog = databricks_catalog.catalog.name

  dynamic "grant" {
    # Flattening the nested JSON structure: [ { grants: [ {principal, privileges} ] } ]
    for_each = flatten([
      for cg in var.catalog_grants : [
        for g in cg.grants : g
      ]
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
}

### 3. Schema Creation
# Standardized creation for all schemas defined in the JSON catalog object.
resource "databricks_schema" "schema" {
  # If the schemas list is empty (as sent by Python for Federated types), 
  # the for_each simply will not execute.
  for_each = { for s in var.catalog.schemas : s.schema_name => s }

  catalog_name  = databricks_catalog.catalog.name
  name          = each.key
  comment       = "Managed by Terraform"
  force_destroy = true
}

### 4. Schema Grants
# Permissions applied to each schema.
# Filters the global schema_grants list by matching "catalog_name.schema_name".
resource "databricks_grants" "schema_grants" {
  for_each = { for s in var.catalog.schemas : s.schema_name => s }
  schema   = "${databricks_catalog.catalog.name}.${each.key}"

  dynamic "grant" {
    for_each = flatten([
      for sg in var.managed_schema_grants : [
        for g in sg.grants : g
      ] if sg.schema == "${databricks_catalog.catalog.name}.${each.key}"
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
  depends_on = [databricks_schema.schema]
}

### 5. Volume Creation (Conditional)
# Creates Volumes only if a "volumes" list is present in the schema definition.
resource "databricks_volume" "volume" {
  # Only processes if the catalog is MANAGED; Federated catalogs do not support Volumes
  for_each = lookup(var.catalog, "type", "MANAGED") == "MANAGED" ? {
    for volume_config in flatten([
      for s in var.catalog.schemas : [
        for v in lookup(s, "volumes", []) : {
          key             = "${s.schema_name}.${v.volume_name}"
          schema_name     = s.schema_name
          v_name          = v.volume_name
          v_type          = v.volume_type
          calculated_path = v.calculated_storage_location # The prepared URI
        }
      ]
    ]) : volume_config.key => volume_config
  } : {}

  name             = each.value.v_name
  catalog_name     = databricks_catalog.catalog.name
  schema_name      = each.value.schema_name
  volume_type      = each.value.v_type
  storage_location = each.value.calculated_path

  depends_on = [
    databricks_schema.schema,
    databricks_catalog.catalog,
    databricks_grants.schema_grants
  ]
}

### 6. Volume Grants
# Permissions applied to each Volume created.
# Filters global volume_grants by matching "catalog.schema.volume".
resource "databricks_grants" "volume_grants" {
  # Filters volumes to keep only those that have at least one grant defined in the JSON
  for_each = {
    for k, v in databricks_volume.volume : k => v
    if length(flatten([
      for vg in var.volume_grants : [for g in vg.grants : g]
      if vg.volume == "${databricks_catalog.catalog.name}.${v.schema_name}.${v.name}"
    ])) > 0
  }
  volume = each.value.id

  dynamic "grant" {
    for_each = flatten([
      for vg in var.volume_grants : [
        for g in vg.grants : g
      ] if vg.volume == "${databricks_catalog.catalog.name}.${each.value.schema_name}.${each.value.name}"
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
}