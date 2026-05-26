# Outputs the map of share keys to their actual Unity Catalog share names
output "share_names" {
  value = { for k, v in databricks_share.this : k => v.name }
}

# Mapping shares for consumption by downstream modules (e.g., AWS side catalogs)
output "shares" {
  # Returns a map containing the share names generated in this module
  value = { for k, v in databricks_share.this : k => v.name }
}