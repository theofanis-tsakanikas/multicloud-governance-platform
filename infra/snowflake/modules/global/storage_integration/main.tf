# Snowflake storage integration — the cloud trust relationship behind external stages.
#
# This is the Snowflake counterpart of `dbx_creds` (databricks_storage_credential): the
# object that lets the engine read the domain's object storage without any credential
# living in the engine. Both engines end up reading the SAME S3 prefixes, which is the
# whole point of ADR-0011 — one governance contract, two enforcement backends.
#
# The AWS side of the trust (the IAM role Snowflake assumes) is created by the caller,
# because it is cloud-specific and this module is cloud-neutral by construction. The two
# halves are joined without a dependency cycle:
#
#   1. The caller derives the role ARN as a *string* (account id + a name it chooses), so
#      nothing here waits on the IAM role to exist.
#   2. Snowflake mints its own IAM user for the integration; we surface it as an output.
#   3. The caller builds the role's trust policy from that output.
#
# The external id is supplied by the caller rather than read back from Snowflake, so the
# trust policy is deterministic and reviewable in a plan.

resource "snowflake_storage_integration_aws" "this" {
  name                      = var.integration_name
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = var.aws_role_arn
  storage_aws_external_id   = var.external_id
  storage_allowed_locations = var.allowed_locations

  comment = "Grants Snowflake read/write on the ${var.domain} domain's external locations."
}
