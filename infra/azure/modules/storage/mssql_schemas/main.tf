data "mssql_database" "target" {
  name = var.sql_database_name
}

resource "mssql_schema" "supply_chain_schemas" {
  for_each    = toset(var.mssql_schemas)
  database_id = data.mssql_database.target.id
  name        = each.value
}


