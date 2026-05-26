# Databricks provider configuration for Unity Catalog administration


locals {
  # Decode raw JSON strings provided by Python into Terraform-native structures
  federated_catalogs_data = jsondecode(var.federated_catalogs_json)
  federated_schema_grants = jsondecode(var.federated_schema_grants_json)
  # Converting the list to map with key the catalog_name
  federated_catalog_map = { for cat in local.federated_catalogs_data : cat.catalog_name => cat }
}

module "federated_grants" {
  source                  = "../../../../databricks/modules/global/federated_grants"
  for_each                = local.federated_catalog_map
  federated_catalog       = each.value
  federated_schema_grants = local.federated_schema_grants
  providers = {
    databricks = databricks.uc_mws
  }
}