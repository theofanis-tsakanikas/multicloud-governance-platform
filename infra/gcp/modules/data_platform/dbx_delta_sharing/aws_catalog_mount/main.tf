locals {
  # Parses the JSON string containing the mapping of GCP shares
  shares = jsondecode(var.delta_shares_map_json)
}

# Resource to create a Foreign Catalog for each entry in the Delta Sharing map
resource "databricks_catalog" "foreign_gcp" {
  for_each = local.shares

  # The name of the catalog in your local workspace (e.g., shared_marketing_data)
  name = "shared_${each.key}"
  # The name of the Delta Sharing Provider established in your Databricks account
  provider_name = var.gcp_provider_name
  # The specific share name exposed by the provider
  share_name = each.value.share_name
}