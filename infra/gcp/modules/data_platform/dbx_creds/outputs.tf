output "storage_credential_id" {
  description = "The unique ID of the storage credential in Unity Catalog."
  value       = databricks_storage_credential.external.id
}

output "storage_credential_name" {
  description = "The name of the storage credential."
  value       = databricks_storage_credential.external.name
}

output "cred_sa_email" {
  description = "IMPORTANT: This is the Google Service Account email created by Databricks. You MUST grant this email 'Storage Object Admin' (or Viewer/Creator) permissions on your GCS Bucket in GCP."
  value       = databricks_storage_credential.external.databricks_gcp_service_account[0].email
}