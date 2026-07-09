# Domain schemas — the Snowflake counterpart of a Unity Catalog schema.
#
# The schema's data classification (public|internal|confidential|pii) travels from the
# domain contract onto a Snowflake object comment AND drives tag-based masking downstream
# (see the masking module). Aggregation of classification into governance tags is what lets
# the same declared "pii" tag produce both a UC column mask and a Snowflake masking policy.

locals {
  schemas = { for s in var.schemas : "${s.database}.${s.schema_name}" => s }
}

resource "snowflake_schema" "schema" {
  for_each = local.schemas

  database = each.value.database
  name     = each.value.schema_name
  comment  = "classification=${lookup(each.value, "classification", "unclassified")}"
}
