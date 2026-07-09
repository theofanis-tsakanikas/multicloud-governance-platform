# RBAC grant enforcement — the Snowflake counterpart of `databricks_grants`.
#
# Each instance was translated from an abstract domain grant through the shared
# privilege_map.json (the same file the Python consistency test reads), so what this module
# applies is provably access-equivalent to the Unity Catalog backend
# (scripts/snowflake_backend.py, tests/test_snowflake_backend.py).
#
# Privileges are listed explicitly (never `all_privileges = true`) so the grant is
# least-privilege by construction; the analyzer gate (policy_analyzer.py) has already
# vetted the abstract contract before either backend applies.
#
# Snowflake data-access privileges live on tables, not on the containing schema, so a
# schema-level SELECT/MODIFY in the contract fans out to ALL + FUTURE tables in the schema
# (the two `*_tables_*` kinds), while USAGE/CREATE stay on the schema itself.

locals {
  by_kind = {
    database             = { for g in var.grant_instances : g.key => g if g.kind == "database" }
    schema               = { for g in var.grant_instances : g.key => g if g.kind == "schema" }
    schema_tables_all    = { for g in var.grant_instances : g.key => g if g.kind == "schema_tables_all" }
    schema_tables_future = { for g in var.grant_instances : g.key => g if g.kind == "schema_tables_future" }
    stage                = { for g in var.grant_instances : g.key => g if g.kind == "stage" }
  }
}

# USAGE / CREATE SCHEMA / ALL PRIVILEGES on a database.
resource "snowflake_grant_privileges_to_account_role" "on_database" {
  for_each = local.by_kind.database

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.object_name
  }
}

# USAGE / CREATE TABLE on a schema (traversal + structural, not table data).
resource "snowflake_grant_privileges_to_account_role" "on_schema" {
  for_each = local.by_kind.schema

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_schema {
    schema_name = each.value.schema
  }
}

# Data-access on all EXISTING tables in a schema (the SELECT/MODIFY read/write path).
resource "snowflake_grant_privileges_to_account_role" "on_schema_tables_all" {
  for_each = local.by_kind.schema_tables_all

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = each.value.schema
    }
  }
}

# Data-access on all FUTURE tables in a schema (so new tables inherit the grant).
resource "snowflake_grant_privileges_to_account_role" "on_schema_tables_future" {
  for_each = local.by_kind.schema_tables_future

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_schema          = each.value.schema
    }
  }
}

# USAGE (read) / WRITE (write) on a stage — the Snowflake home of volumes and external locations.
resource "snowflake_grant_privileges_to_account_role" "on_stage" {
  for_each = local.by_kind.stage

  account_role_name = each.value.role_name
  privileges        = each.value.privileges

  on_schema_object {
    object_type = "STAGE"
    object_name = each.value.object_name
  }
}
