output "metastore_bucket_name" {
  value       = google_storage_bucket.unity_metastore.name
  description = "The name of the created GCS bucket for Unity Catalog"
}

output "dbx_sa_email" {
  value       = google_service_account.dbx_sa.email
  description = "The email address of the created Google Service Account"
}

output "dbx_sa_id" {
  value       = google_service_account.dbx_sa.name
  description = "The full resource ID of the created Google Service Account"
}
