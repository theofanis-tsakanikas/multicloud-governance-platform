# ─── Lakehouse Federation: Unity Catalog connection to the Azure SQL Server ────
#
# Creates the UC CONNECTION only. The FEDERATED catalog (supply_sql_master) is
# created in the Azure dbx_governance layer via the global/catalog module, binding
# to this connection by name — the live Azure SQL database as a governed UC catalog,
# no data movement.

resource "databricks_connection" "azure_sql" {
  name            = var.connection_name
  connection_type = "SQLSERVER"
  comment         = "Federated connection to the Azure SQL Server"

  options = {
    host     = var.sql_server_host
    port     = "1433"
    user     = var.sql_admin_user
    password = var.sql_admin_password
  }
}
