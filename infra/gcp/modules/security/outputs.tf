output "bq_sa_key" {
  description = "Federation service-account key JSON; consumed by dbx_bq_connector."
  value       = module.service_account.bq_sa_key
  sensitive   = true
}

output "federation_sa_email" {
  description = "Email of the BigQuery federation service account."
  value       = module.service_account.federation_sa_email
}
