# Outputs for use in subsequent Databricks setup modules
output "gcs_bucket_name" {
  value       = google_storage_bucket.this.name
  description = "The name of the bucket"
}

output "gcs_bucket_url" {
  value       = "gs://${google_storage_bucket.this.name}"
  description = "The GS URI of the bucket for Databricks External Location"
}