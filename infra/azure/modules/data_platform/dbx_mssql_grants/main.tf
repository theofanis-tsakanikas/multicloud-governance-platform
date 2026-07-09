


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
  workspace_host          = var.dbx_workspace_host
  warehouse_id            = var.warehouse_id
  spn_client_id           = var.spn_client_id
  spn_client_secret       = var.spn_client_secret
  providers = {
    databricks = databricks.uc_admin
  }
}