# Stages — the Snowflake home of Unity Catalog external locations and volumes.
#
# A UC external location (an S3/ADLS/GCS path) maps to a Snowflake EXTERNAL STAGE bound to a
# storage integration; a UC volume maps to an INTERNAL STAGE inside its schema. The storage
# integration itself is provisioned by a separate creds/bootstrap layer and passed in by
# name — mirroring how the UC backend receives a `storage_credential_name` from `dbx_creds`
# (governance-as-code does not own the cloud trust relationship).
#
# External stages live in a dedicated `_EXTERNAL` governance schema so their grants have a
# stable schema-qualified home, since external locations are domain-scoped, not schema-scoped.

resource "snowflake_schema" "external" {
  count = length(var.external_stages) > 0 ? 1 : 0

  database = var.database
  name     = var.external_schema_name
  comment  = "Governance schema holding external stages for the domain's external locations."
}

resource "snowflake_stage_external_s3" "external" {
  for_each = { for s in var.external_stages : s.name => s }

  database            = var.database
  schema              = var.external_schema_name
  name                = each.value.name
  url                 = each.value.url
  storage_integration = var.storage_integration_name
  comment             = "External stage for domain external location '${each.key}'."

  depends_on = [snowflake_schema.external]
}

resource "snowflake_stage_internal" "internal" {
  for_each = { for s in var.internal_stages : s.key => s }

  database = each.value.database
  schema   = each.value.schema
  name     = each.value.name
  comment  = "Internal stage for domain volume '${each.key}'."
}
