resource "postgresql_schema" "rds_schemas" {
  for_each = toset(var.rds_schemas)
  name     = each.value
}