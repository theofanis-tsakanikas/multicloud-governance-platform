


module "azure_sql_databricks_connection" {
  source = "./dbx_mssql_connector"
  # Authentication & Secrets
  sql_password_value = var.sql_admin_password
  sql_password_name  = var.sql_password_name
  # Server Details
  sql_server_host   = var.sql_server_host
  sql_admin_user    = var.sql_admin_user
  sql_database_name = var.sql_database_name
  connection_name   = var.connection_name
}


