output "share_names" {
  value = module.gcp_side.share_names
}

// output "gcp_metastore_id" {
//   value = module.gcp_side.gcp_metastore_id
// }

output "shares" {
  # Return a map of share names consumed by the downstream module
  value = module.gcp_side.shares
}