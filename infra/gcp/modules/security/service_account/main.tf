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
# ─── The Lakehouse Federation identity for BigQuery ──────────────────────────
#
# Databricks authenticates to BigQuery with a service-account key (the connection
# option is GoogleServiceAccountKeyJson), so the key has to exist. Nothing created
# it: dbx_bq_connector read `bq_key` out of GCP Secret Manager and the secret was
# never provisioned.
#
# Created here, in the security layer, alongside the other grants — and with the
# two roles federation actually needs rather than roles/bigquery.admin.
resource "google_service_account" "federation" {
  project      = var.project_id
  account_id   = var.federation_sa_id
  display_name = "Databricks Lakehouse Federation (BigQuery)"
  description  = "Read-only BigQuery identity used by the marketing_bq_fed foreign catalog."
}

# Least privilege, and it takes three roles rather than the one obvious one.
#
#   dataViewer      read the tables
#   jobUser         submit the queries that read them
#   readSessionUser open a BigQuery Storage Read API session
#
# The third is easy to miss and impossible to guess: Databricks reads a federated
# BigQuery table through the Storage Read API, not through the query API, and
# jobUser does not carry bigquery.readsessions.create. Without it the medallion
# fails at the first SELECT with PERMISSION_DENIED, long after the catalog has
# been created and the schemas discovered.
#
# All three together are still far short of roles/bigquery.admin: this identity
# can read, and cannot create, alter or delete anything.
resource "google_project_iam_member" "federation_bq_data" {
  project = var.project_id
  role    = "roles/bigquery.dataViewer"
  member  = "serviceAccount:${google_service_account.federation.email}"
}

resource "google_project_iam_member" "federation_bq_jobs" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.federation.email}"
}

resource "google_project_iam_member" "federation_bq_read_sessions" {
  project = var.project_id
  role    = "roles/bigquery.readSessionUser"
  member  = "serviceAccount:${google_service_account.federation.email}"
}

resource "google_service_account_key" "federation" {
  service_account_id = google_service_account.federation.name
}

# Stored in GCP's own secret store so the key has one canonical home and can be
# rotated there. The connector reads it as a dependency output, not from here —
# the secret exists for operators, not for the apply.
resource "google_secret_manager_secret" "bq_key" {
  project   = var.project_id
  secret_id = var.bq_secret_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "bq_key" {
  secret      = google_secret_manager_secret.bq_key.id
  secret_data = base64decode(google_service_account_key.federation.private_key)
}
