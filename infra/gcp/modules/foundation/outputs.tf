output "gcs_bucket_name" {
  description = "Bucket backing the Unity Catalog external locations on GCP."
  value       = module.gcs_bucket.gcs_bucket_name
}

output "gcs_bucket_url" {
  description = "gs:// URL of the bucket."
  value       = module.gcs_bucket.gcs_bucket_url
}
