# 1. Metastore Creation (GCP Version)
resource "databricks_metastore" "this" {
  name = var.metastore_name
  # The GCS path used for managed tables (e.g., gs://bucket-name/metastore)
  storage_root  = var.metastore_storage_root
  region        = var.location
  force_destroy = false

  # Delta Sharing configuration for internal and external data exchange
  delta_sharing_organization_name                   = var.gcp_delta_sharing_name
  delta_sharing_scope                               = "INTERNAL_AND_EXTERNAL"
  delta_sharing_recipient_token_lifetime_in_seconds = var.delta_sharing_token_lifetime

  # Assigns administrative ownership to the Admin Group
  owner = var.admin_group_name
}



# 2. Data Access for GCP (Identity Bridge)
resource "databricks_metastore_data_access" "this" {
  metastore_id = databricks_metastore.this.id
  name         = "metastore-data-access"
  is_default   = true

  # KEY CHANGE:
  # Instead of an AWS IAM Role, we use the System-Managed GCP Service Account.
  # Leaving this block empty allows Databricks to generate a unique GCP SA.
  databricks_gcp_service_account {
    # email = var.dbx_sa_email
  }
}

# Essential delay to allow GCP IAM changes to propagate
resource "time_sleep" "wait_after_metastore" {
  depends_on = [databricks_metastore_data_access.this]

  create_duration = "45s"
}

# 3. Grant Storage Permissions to the newly generated Service Account email
resource "google_storage_bucket_iam_member" "metastore_access" {
  # The target bucket for the Metastore's root storage
  bucket = var.metastore_bucket_name
  role   = "roles/storage.objectAdmin"

  # We extract the email directly from the resource that was just created!
  member     = "serviceAccount:${databricks_metastore_data_access.this.databricks_gcp_service_account[0].email}"
  depends_on = [time_sleep.wait_after_metastore]
}

# 4. Grant Token Creation rights (Impersonation)
resource "google_service_account_iam_member" "dbx_sa_token_creator" {
  service_account_id = var.dbx_sa_id
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${databricks_metastore_data_access.this.databricks_gcp_service_account[0].email}"
  depends_on         = [time_sleep.wait_after_metastore]
}

# 5. Grant Service Account User rights
# Required for Unity Catalog to validate and use the Storage Credential effectively.
resource "google_service_account_iam_member" "dbx_sa_user" {
  service_account_id = var.dbx_sa_id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${databricks_metastore_data_access.this.databricks_gcp_service_account[0].email}"
  depends_on         = [time_sleep.wait_after_metastore]
}