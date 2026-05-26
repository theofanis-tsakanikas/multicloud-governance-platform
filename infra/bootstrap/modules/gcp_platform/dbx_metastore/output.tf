output "gcp_metastore_id" {
  value       = databricks_metastore.this.id
  description = "The unique identifier of the Unity Catalog Metastore"
}

output "metastore_data_access_id" {
  value       = databricks_metastore_data_access.this.id
  description = "The ID of the Metastore Data Access configuration"
}

output "metastore_storage_root" {
  value       = databricks_metastore.this.storage_root
  description = "The storage root URL (GCS) used by the Metastore"
}

output "delta_sharing_config" {
  value = {
    scope          = databricks_metastore.this.delta_sharing_scope
    token_lifetime = databricks_metastore.this.delta_sharing_recipient_token_lifetime_in_seconds
  }
  description = "The Delta Sharing configuration parameters for this Metastore"
}

output "uc_sa_email" {
  value       = databricks_metastore_data_access.this.databricks_gcp_service_account[0].email
  description = "The system-generated GCP Service Account for Unity Catalog"
}