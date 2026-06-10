

locals {
  # Decode raw JSON strings provided by Python into Terraform-native lists/maps
  external_locations_data = jsondecode(var.external_locations_json)
  ext_loc_grants_data     = jsondecode(var.ext_loc_grants_json)

  # Convert list to map using the 'name' as key to enable for_each iteration
  loc_map = {
    for loc in local.external_locations_data : loc.location_name => merge(loc, {
      # Path calculation for Azure: abfss://container@account.dfs.core.windows.net/path
      calculated_url = "abfss://${loc.container}@${var.azure_storage_account_name}.dfs.core.windows.net/${trim(loc.path, "/")}/${var.deployment_id_azure}/"

      # Unique Name Calculation (Injecting the deployment_id_azure)
      # If loc.location_name is "sales_raw", the final result will be "sales_raw_a1b2c3d4"
      unique_name = "${loc.location_name}_${var.deployment_id_azure}"
    })
  }

  # Decode Catalog and Governance (Grants) data structures
  catalogs_data              = jsondecode(var.catalogs_json)
  catalog_grants_data        = jsondecode(var.catalog_grants_json)
  managed_schema_grants_data = jsondecode(var.managed_schema_grants_json)
  volume_grants_data         = jsondecode(var.volume_grants_json)

  # Create a map of catalogs for resource-level iteration
  catalog_map = { for cat in local.catalogs_data : cat.catalog_name => cat }

  # Enrich catalog data with prepared URIs for Azure storage
  enriched_catalogs = {
    for cat_name, cat in local.catalog_map : cat_name => merge(cat, {
      # 1. Calculation of Catalog Storage Root
      calculated_storage_root = cat.type == "MANAGED" ? (
        lookup(cat, "storage_root", null) != null ?
        "abfss://${cat.container}@${var.azure_storage_account_name}.dfs.core.windows.net/${trim(cat.storage_root, "/")}/${var.deployment_id_azure}/" :
        "abfss://${var.managed_storage_container}@${var.azure_storage_account_name}.dfs.core.windows.net/${trim(var.managed_storage_root, "/")}/${var.deployment_id_azure}/"
      ) : null

      # 2. Calculation of Volume Storage Locations inside schemas
      schemas = [
        for s in lookup(cat, "schemas", []) : merge(s, {
          volumes = [
            for v in lookup(s, "volumes", []) : merge(v, {
              calculated_storage_location = lookup(v, "volume_type", "MANAGED") == "EXTERNAL" ? (
                "abfss://${v.container}@${var.azure_storage_account_name}.dfs.core.windows.net/${trim(v.location_path, "/")}/${var.deployment_id_azure}/${trim(v.volume_path, "/")}/"
              ) : null
            })
          ]
        })
      ]
    })
  }
}



### 1. Azure External Locations Module
module "external_locations" {
  source                  = "../../../../databricks/modules/global/external_location"
  for_each                = local.loc_map
  storage_credential_name = var.storage_credential_name
  location_name           = each.value.unique_name
  calculated_url          = each.value.calculated_url

  # Filtering: Pass only the grants belonging to the current location being processed
  external_location_grants = [
    for grant in local.ext_loc_grants_data : grant
    if grant.location_name == each.key
  ]

  providers = {
    databricks = databricks.uc_mws
  }
}

### 2. Azure Managed Catalog Module
module "azure_catalog" {
  source   = "../../../../databricks/modules/global/catalog"
  for_each = local.enriched_catalogs

  catalog              = each.value
  managed_storage_root = var.managed_storage_root

  # Filtering: Pass only catalog-level permissions for the current catalog
  catalog_grants = [
    for g in local.catalog_grants_data : g
    if g.catalog_name == each.key
  ]

  # Pass full lists of schema/volume grants; the module will filter internally 
  # based on the fully-qualified name (catalog.schema.volume)
  managed_schema_grants = local.managed_schema_grants_data
  volume_grants         = local.volume_grants_data

  providers = {
    databricks = databricks.uc_mws
  }

  depends_on = [module.external_locations]
}