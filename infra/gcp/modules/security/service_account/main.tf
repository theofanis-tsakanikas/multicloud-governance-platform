# Grants the Databricks Service Account administrative access to a specific GCS Bucket
resource "google_storage_bucket_iam_member" "sa_data_bucket_access" {
  # The name of the GCS bucket where your data files (Delta, Parquet, etc.) are stored
  bucket = var.gcs_bucket_name
  # Provides full control over objects in the bucket, allowing Databricks to read/write data
  role = "roles/storage.objectAdmin"
  # The email address of the Service Account created for Databricks
  member = "serviceAccount:${var.dbx_sa_email}"
}

# Grants the Databricks Service Account access to BigQuery at the project level
resource "google_project_iam_member" "sa_bq_access" {
  project = var.project_id
  # Provides administrative access to BigQuery; alternatively, use roles/bigquery.user 
  # combined with dataViewer for more restrictive read-only access.
  role   = "roles/bigquery.admin"
  member = "serviceAccount:${var.dbx_sa_email}"
}