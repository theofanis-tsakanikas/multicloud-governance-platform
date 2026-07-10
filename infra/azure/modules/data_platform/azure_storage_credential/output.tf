output "storage_credential_id" {
  description = "The unique identifier of the Storage Credential"
  value       = databricks_storage_credential.azure_adls_creds.id
}

# Named to match the aws and gcp modules; dbx_governance reads this on all
# three clouds via dependency.dbx_creds.outputs.storage_credential_name.
output "storage_credential_name" {
  description = "The name of the Storage Credential used by Unity Catalog"
  value       = databricks_storage_credential.azure_adls_creds.name
}