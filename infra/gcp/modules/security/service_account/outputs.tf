output "bq_sa_key" {
  description = "The federation service-account key JSON, consumed by dbx_bq_connector."
  value       = base64decode(google_service_account_key.federation.private_key)
  sensitive   = true
}

output "federation_sa_email" {
  description = "Email of the BigQuery federation service account."
  value       = google_service_account.federation.email
}
