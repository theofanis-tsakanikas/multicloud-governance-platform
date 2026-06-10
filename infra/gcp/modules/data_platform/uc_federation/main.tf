# Databricks provider for GCP Workspace-level Foreign Catalog management


locals {
  catalogs_data       = jsondecode(var.catalogs_json)
  catalog_grants_data = jsondecode(var.catalog_grants_json)

  # Create a map of catalogs for resource-level iteration
  catalog_map = { for cat in local.catalogs_data : cat.catalog_name => cat }

  # Enriching the catalogs to ensure they are compatible with the child module
  enriched_catalogs = {
    for cat_name, cat in local.catalog_map : cat_name => merge(cat, {
      # 1. We empty the schemas list because in Federation, 
      # Databricks mirrors them automatically from the source
      schemas = []

      # 2. We ensure these keys exist, even if they are missing from the JSON,
      # so that the child module's object type does not throw an error
      database_name   = lookup(cat, "database_name", null)
      connection_name = lookup(cat, "connection_name", null)
    })
  }
}


# 1. Foreign Catalog Creation
# Provisions the catalog object in Unity Catalog pointing to the external connection
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

# 2. Workspace Binding
# Links the federated catalog to specific managed workspaces
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