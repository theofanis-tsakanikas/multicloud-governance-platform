# GCP storage — the BigQuery datasets the federated catalog exposes.
#
# SIMULATED SOURCE SYSTEM (ADR-0014): these datasets stand in for a BigQuery
# project an analytics team owns. `marketing_bq_fed` federates over them; Unity
# Catalog discovers their contents rather than this repo declaring them.

module "bigquery" {
  source     = "./bigquery"
  project_id = var.project_id
  location   = var.location
  datasets   = var.datasets
}
