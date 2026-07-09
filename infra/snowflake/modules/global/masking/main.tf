# Governance policies — tag-based masking + row access, derived from data classification.
#
# The Snowflake counterpart of the Unity Catalog column-mask story: the SAME declared
# classification ("pii" / "confidential") that drives the analyzer's PII rules and (on the
# UC backend) a column mask, here produces a Snowflake MASKING POLICY attached to a
# governance TAG (tag-based masking). Tagging a column with a masked classification then
# masks it on read — full value to the privileged role, redacted to everyone else.
#
# Everything lives in one dedicated `_GOVERNANCE` schema so the policies have a stable home.

resource "snowflake_schema" "governance" {
  database = var.database
  name     = var.governance_schema_name
  comment  = "Holds masking policies, the classification tag, and row-access policies (governance-as-code)."
}

# One masking policy per masked classification (full value to the privileged role only).
resource "snowflake_masking_policy" "classification" {
  database = var.database
  schema   = snowflake_schema.governance.name
  name     = "mask_classification"

  argument {
    name = "val"
    type = "VARCHAR"
  }

  body             = "case when is_role_in_session('${var.privileged_role}') then val else '***REDACTED***' end"
  return_data_type = "VARCHAR"
  comment          = "Masks classified values for principals outside '${var.privileged_role}'. One policy per data type — a tag allows only one masking policy per type."
}

# The classification governance tag; masked classifications carry their masking policy, so a
# column tagged 'pii' is masked automatically (tag-based masking — the scalable pattern).
resource "snowflake_tag" "classification" {
  database               = var.database
  schema                 = snowflake_schema.governance.name
  name                   = "data_classification"
  comment                = "Data classification governance tag; masked values carry a masking policy."
  ordered_allowed_values = ["public", "internal", "confidential", "pii"]
  masking_policies       = [snowflake_masking_policy.classification.fully_qualified_name]
}

# Tag each classified schema with its classification (propagates to columns as tables are built).
resource "snowflake_tag_association" "schema_classification" {
  for_each = { for s in var.classified_schemas : s.schema => s }

  object_identifiers = [each.value.schema]
  object_type        = "SCHEMA"
  tag_id             = snowflake_tag.classification.fully_qualified_name
  tag_value          = each.value.classification
}

# Domain-scoped row-access policy scaffold: the privileged role sees all rows; others are
# gated by an entitlement predicate (bound to a real column when tables are onboarded).
resource "snowflake_row_access_policy" "domain" {
  database = var.database
  schema   = snowflake_schema.governance.name
  name     = "rap_${var.domain}"

  argument {
    name = "entitlement"
    type = "VARCHAR"
  }

  body    = "case when is_role_in_session('${var.privileged_role}') then true else entitlement = current_role() end"
  comment = "Row-access policy for domain '${var.domain}' (bind to an entitlement column at table onboarding)."
}
