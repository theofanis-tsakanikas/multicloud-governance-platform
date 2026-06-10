# 1. Create the Storage Credential in Unity Catalog
resource "databricks_storage_credential" "external" {
  name = "${var.gcp_storage_credential_name}_${var.deployment_id}"

  # Uses the Databricks-managed Service Account (System Managed)
  databricks_gcp_service_account {
    # email = var.dbx_sa_email
  }
}



# 2. Assign Permissions (Grants) at the Unity Catalog level
resource "databricks_grants" "external_creds" {
  storage_credential = databricks_storage_credential.external.id

  # Grants the admin group full control over this credential
  grant {
    principal  = var.admin_group_name
    privileges = ["ALL_PRIVILEGES"]
  }
}

# 3. Grant the NEW system email permission to "impersonate" your Service Account
resource "google_service_account_iam_member" "external_creds_impersonation" {
  # The ID of your existing SA (the one created during bootstrap)
  service_account_id = var.dbx_sa_id

  role = "roles/iam.serviceAccountTokenCreator"

  # The system-managed email created by the databricks_storage_credential resource
  member = "serviceAccount:${databricks_storage_credential.external.databricks_gcp_service_account[0].email}"
}

# 4. Grant the system-managed email access to the GCS Data Bucket
resource "google_storage_bucket_iam_member" "sa_data_bucket_access" {
  bucket = var.gcs_bucket_name
  role   = "roles/storage.objectAdmin"

  # Uses the dynamic email generated for this specific credential
  member = "serviceAccount:${databricks_storage_credential.external.databricks_gcp_service_account[0].email}"
}

# 5. Grant the system-managed email access to BigQuery
resource "google_project_iam_member" "sa_bq_access" {
  project = var.project_id
  role    = "roles/bigquery.admin" # Or roles/bigquery.user + dataViewer
  member  = "serviceAccount:${databricks_storage_credential.external.databricks_gcp_service_account[0].email}"
}