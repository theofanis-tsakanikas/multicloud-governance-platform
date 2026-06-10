# Resource to create one or more BigQuery Datasets based on a list of names
resource "google_bigquery_dataset" "dataset" {
  # Iterates through the provided list of dataset names (e.g., ["sales", "finance"])
  for_each = toset(var.datasets)

  dataset_id = each.value
  location   = var.location
  project    = var.project_id

  # Metadata for the Google Cloud Console
  friendly_name = "Dataset for ${each.value}"
  description   = "Managed by Terraform - Databricks Federation"

  # SECURITY: If set to true, 'terraform destroy' will also delete all tables inside.
  # WARNING: Set this to false in Production environments to prevent data loss!
  delete_contents_on_destroy = true

  # Resource labeling for cost tracking and environment organization
  labels = {
    env      = "dev"
    managed  = "terraform"
    platform = "databricks"
  }
}


