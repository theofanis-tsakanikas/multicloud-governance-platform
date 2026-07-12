# ─── BigQuery, federated into the AWS serverless workspace ──────────────────────────────────────
#
# WHY THIS EXISTS
#
# The other BigQuery connector (dbx_bq_connector) creates its connection in the *GCP* Databricks
# workspace, because the GCP medallion runs there: it reads marketing_bq_fed, builds
# gold_marketing_by_market, and Delta-Shares it to AWS. That is a real and separate job.
#
# But it means the AWS serverless workspace — the one that federates RDS over PrivateLink and Azure
# SQL over the transit hub — never queried BigQuery at all. It read the Delta Share instead. So the
# BigQuery transit hub, once built, carried no traffic: the NCC rule routes googleapis for AWS
# serverless compute, and AWS serverless compute had no reason to call googleapis.
#
# This closes that gap. The AWS workspace gets its own BIGQUERY connection and its own FEDERATED
# catalog, and every query against it leaves through the NCC private endpoint → PrivateLink → the
# gateway → the VPN → Google's private API VIP. Which makes the claim the platform wants to make
# actually true:
#
#     One serverless workspace. Three source databases. Three private paths.
#
#   sales_rds_fed      → RDS Postgres   over AWS PrivateLink
#   supply_sql_master  → Azure SQL      over the Azure transit hub
#   marketing_bq_fed   → BigQuery       over the GCP transit hub   ← this file
#
# It is additive: the GCP workspace keeps its own catalog and its own medallion, and the Delta Share
# keeps working exactly as it did. Nothing that was green stops being green.
#
# The catalog name matches the GCP one on purpose. They live in different metastores — the AWS
# metastore in eu-central-1 and the GCP metastore in europe-west3 — so there is no collision, and
# the same domain contract naming the same source twice is the point, not an accident.

resource "databricks_connection" "bigquery" {
  name            = var.connection_name
  connection_type = "BIGQUERY"
  comment         = "Federated connection to BigQuery — private in private mode, over the transit hub"

  options = {
    GoogleServiceAccountKeyJson = var.bq_key
    projectId                   = var.project_id
  }
}

resource "databricks_catalog" "marketing_bq_fed" {
  name            = var.catalog_name
  connection_name = databricks_connection.bigquery.name
  comment         = "FEDERATED catalog — BigQuery read where it lives. In private mode every query crosses the transit hub, never the public internet."

  # A foreign catalog holds no bytes of its own, so there is nothing to force-destroy but the
  # pointer. Dropping it leaves BigQuery untouched, which is the entire idea.
  force_destroy = true

  depends_on = [databricks_connection.bigquery]
}

# Least privilege, in the same vocabulary as every other grant here: the engineers who build the
# medallion may read it. Nobody gets more.
resource "databricks_grants" "marketing_bq_fed" {
  catalog = databricks_catalog.marketing_bq_fed.name

  dynamic "grant" {
    for_each = var.reader_groups
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
    }
  }
}
