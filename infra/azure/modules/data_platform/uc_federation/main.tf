# Databricks provider for Workspace-level Foreign Catalog management


locals {
  catalogs_data       = jsondecode(var.catalogs_json)
  catalog_grants_data = jsondecode(var.catalog_grants_json)

  # Create a map of catalogs for resource-level iteration
  catalog_map = { for cat in local.catalogs_data : cat.catalog_name => cat }

  # Enrich catalogs to ensure compatibility with the child module structure
  enriched_catalogs = {
    for cat_name, cat in local.catalog_map : cat_name => merge(cat, {
      # 1. We clear the schemas list because in Lakehouse Federation, 
      # Databricks mirrors them automatically from the source.
      schemas = []

      # 2. Ensure these keys exist even if missing from the JSON input
      # to prevent "type object" schema errors in the child module.
      database_name   = lookup(cat, "database_name", null)
      connection_name = lookup(cat, "connection_name", null)
    })
  }
}

# 1. Foreign Catalog Provisioning
# Creates the Catalog object in Unity Catalog linked to an external Connection
module "catalog" {
  source   = "../../../../databricks/modules/global/catalog"
  for_each = local.enriched_catalogs

  catalog = each.value

  # Filtering: Pass only catalog-level permissions for the current catalog
  catalog_grants = [
    for g in local.catalog_grants_data : g
    if g.catalog_name == each.key
  ]

  providers = {
    databricks = databricks.uc_mws
  }
}

# 2. Catalog Binding (Isolation)
# Assigns the Foreign Catalog to specific workspaces to maintain data isolation
module "federated_catalog_binding" {
  source = "./uc_federation"

  for_each             = local.enriched_catalogs
  catalog_name         = module.catalog[each.key].catalog_name
  managed_workspace_id = var.managed_workspace_id
  binding_type         = var.binding_type

  providers = {
    databricks = databricks.uc_mws
  }

  depends_on = [module.catalog]
}