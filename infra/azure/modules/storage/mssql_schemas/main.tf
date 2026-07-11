# ⚠ PRIVATE MODE: this layer creates nothing, and cannot.
#
# public_network_access_enabled = false leaves the SQL server with no public address, and the
# firewall list is empty, so a GitHub runner has no route to it — exactly as with the private
# RDS. The pgssoft/mssql provider here would open a TDS connection from CI and hang. So the
# schemas move to where the database is reachable: a one-shot ECS task on the sql-gateway image,
# inside the AWS VPC that the transit hub bridges to Azure over the VPN. See the deploy workflow.
#
# These schemas belong to a SIMULATED source system (ADR-0014) whose tables have always been
# seeded from outside Terraform; only the schemas were ever in here, and only because public mode
# could reach the server. Private mode removes that accident.
locals {
  schemas = var.is_private_connection ? toset([]) : toset(var.mssql_schemas)
}

data "mssql_database" "target" {
  count = var.is_private_connection ? 0 : 1
  name  = var.sql_database_name
}

resource "mssql_schema" "supply_chain_schemas" {
  for_each    = local.schemas
  database_id = data.mssql_database.target[0].id
  name        = each.value
}


