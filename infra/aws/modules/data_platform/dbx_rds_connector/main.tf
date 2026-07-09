# ─── Lakehouse Federation: Unity Catalog connection to the sales RDS Postgres ──
#
# This creates the UC CONNECTION only. The FEDERATED catalog (sales_rds_fed) is
# created in the dbx_governance layer via the global/catalog module — it binds to
# this connection by name and exposes the live RDS database as a queryable UC
# catalog: same PII/RBAC governance, no data movement.
#
# In public mode `rds_hostname` is the direct RDS endpoint; in private mode it is
# the Route53 custom DNS that routes over the NCC/PrivateLink NLB.

resource "databricks_connection" "rds_postgres" {
  name            = var.rds_connection_name
  connection_type = "POSTGRESQL"
  comment         = "Federated connection to the sales RDS Postgres database"

  options = {
    host     = var.rds_hostname
    port     = tostring(var.rds_port)
    user     = var.rds_username
    password = var.password
  }
}
