output "storage_credential_id" {
  description = "The unique identifier of the Storage Credential"
  value       = databricks_storage_credential.azure_adls_creds.id
}

output "azure_storage_credential_name" {
  description = "The name of the Storage Credential used by Unity Catalog"
  value       = databricks_storage_credential.azure_adls_creds.name
}