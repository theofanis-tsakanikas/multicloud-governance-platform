# Functional account roles — one per governance principal (group).
#
# The domain contract grants to named groups (data_engineers, analysts, ...). The
# Snowflake backend mirrors that shape exactly: each principal becomes a Snowflake
# functional account role, and privileges are granted to it (see the grants module).
# Keeping the RBAC shape aligned with Unity Catalog is what makes the two backends
# provably equivalent (scripts/snowflake_backend.py). Users are assigned to these
# functional roles out-of-band (identity plane), not by this governance layer.

locals {
  # Snowflake unquoted identifiers fold to upper case; normalise here so grant
  # targets and role names match deterministically. "-" is not identifier-safe.
  role_names = { for p in var.principals : p => upper(replace("${var.role_prefix}_${p}", "-", "_")) }
}

resource "snowflake_account_role" "functional" {
  for_each = local.role_names

  name    = each.value
  comment = "Functional role for governance principal '${each.key}' (mirrors the Unity Catalog group)."
}
