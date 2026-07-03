# Domain databases — the Snowflake counterpart of a Unity Catalog MANAGED catalog.
#
# FEDERATED catalogs (a Databricks Lakehouse Federation connection to an external RDBMS)
# have no faithful single-resource Snowflake equivalent — they map to a data share or an
# externally-managed database — so they are handled out of scope and filtered upstream by
# the wrapper module (only MANAGED catalogs reach here), mirroring how the UC backend
# filters MANAGED vs FEDERATED.

locals {
  databases = { for c in var.catalogs : c.catalog_name => c }
}

resource "snowflake_database" "db" {
  for_each = local.databases

  name    = each.value.catalog_name
  comment = "Domain database (managed) — governance-as-code. Owner: ${lookup(each.value, "owner", "unassigned")}."
}
