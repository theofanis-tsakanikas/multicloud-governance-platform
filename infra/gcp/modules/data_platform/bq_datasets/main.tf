# BigQuery datasets for the federated (foreign) catalog to expose.
# The foreign catalog marketing_bq_fed maps to this GCP project; each dataset
# here surfaces as a schema in that catalog (parallel to the AWS rds_schemas /
# Azure mssql_schemas layers). Tables/rows are seeded separately.
resource "google_bigquery_dataset" "fed" {
  for_each                   = toset(var.datasets)
  dataset_id                 = each.value
  project                    = var.project_id
  location                   = var.location
  delete_contents_on_destroy = true
}
