# GCS Bucket for the Root Storage (DBFS/Metastore Root)
resource "google_storage_bucket" "unity_metastore" {
  name          = "${var.metastore_bucket_name}-${var.project_id}"
  location      = var.location
  force_destroy = true
  # Uniform bucket-level access is a standard requirement for Unity Catalog
  uniform_bucket_level_access = true
}

# The Databricks "Identity" Service Account in GCP
resource "google_service_account" "dbx_sa" {
  account_id   = var.dbx_sa_name
  display_name = "Databricks Unity Catalog Service Account"
}

# Grant the Service Account full object management over the metastore bucket
resource "google_storage_bucket_iam_member" "versioning_retention" {
  bucket = google_storage_bucket.unity_metastore.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dbx_sa.email}"
}

# Allow the Terraform executor to impersonate the UC Service Account
resource "google_service_account_iam_member" "terraform_sa_impersonation" {
  # The target SA to be impersonated (the UC access SA)
  service_account_id = google_service_account.dbx_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  # The identity currently running the Terraform code
  member = "serviceAccount:${var.terraform_sa_account}"
}

# Allow the Terraform executor to use the Service Account
resource "google_service_account_iam_member" "dbx_sa_user" {
  service_account_id = google_service_account.dbx_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_sa_account}"
}

# Allow the Databricks System SA to impersonate our custom Service Account
resource "google_service_account_iam_member" "dbx_system_sa_impersonation" {
  # The target SA to be impersonated (the UC access SA)
  service_account_id = google_service_account.dbx_sa.name
  role               = "roles/iam.serviceAccountTokenCreator"
  # The Databricks system identity
  member = "serviceAccount:${var.dbx_system_sa}"
}