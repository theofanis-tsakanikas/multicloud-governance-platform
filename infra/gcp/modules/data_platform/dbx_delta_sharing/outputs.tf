output "share_names" {
  value = module.gcp_side.share_names
}

// output "gcp_metastore_id" {
//   value = module.gcp_side.gcp_metastore_id
// }

output "shares" {
  # Επιστρέφουμε ένα map με τα ονόματα των shares για το επόμενο module
  value = module.gcp_side.shares
}