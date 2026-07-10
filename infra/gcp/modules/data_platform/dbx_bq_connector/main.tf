# ─── Lakehouse Federation: Unity Catalog connection to BigQuery ────────────────
#
# Creates the UC CONNECTION only. The FEDERATED catalog (marketing_bq_fed) is
# created in the GCP dbx_governance layer via the global/catalog module, binding
# to this connection by name — live BigQuery datasets as a governed UC catalog,
# no data movement. Auth is a Google service-account key (fetched from GCP Secret
# Manager in the terragrunt layer).

resource "databricks_connection" "bigquery" {
  name            = var.connection_name
  connection_type = "BIGQUERY"
  comment         = "Federated connection to BigQuery"

  options = {
    GoogleServiceAccountKeyJson = var.bq_key
    projectId                   = var.project_id
  }
}
