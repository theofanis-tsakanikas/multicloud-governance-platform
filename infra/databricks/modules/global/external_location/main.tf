locals {
  # This module is cloud-neutral — AWS, Azure and GCP all call it — so its comment has to be
  # too. It used to read "External location for Azure ADLS Gen2 data federation" no matter what,
  # which is what every S3 and GCS location in the catalog then said about itself. The comment is
  # the first thing a reader sees in Catalog Explorer; a governance platform whose own metadata
  # lies about which cloud the bytes are on has a credibility problem, not a cosmetic one.
  #
  # The URL already knows. Read it from there rather than being told.
  scheme = split("://", var.calculated_url)[0]
  store = lookup({
    s3    = "S3"
    abfss = "ADLS Gen2"
    gs    = "GCS"
  }, local.scheme, local.scheme)
}

# Registers a storage path as a Unity Catalog External Location — the governed boundary between
# the catalog and the bytes. One of:
#   s3://bucket/prefix/
#   abfss://container@account.dfs.core.windows.net/prefix/   (the ABFSS driver, ADLS Gen2)
#   gs://bucket/prefix/
resource "databricks_external_location" "location" {
  name = var.location_name
  url  = var.calculated_url

  # References the Storage Credential (the IAM role / service principal / service account link)
  credential_name = var.storage_credential_name

  comment = "Governed external location over ${local.store} — ${var.calculated_url}"

  # Ensures that if the resource is deleted via Terraform, dependent objects are also handled
  force_destroy = true

  lifecycle {
    create_before_destroy = false
  }
}

# Resource to manage granular access control for the External Location
resource "databricks_grants" "some" {
  external_location = databricks_external_location.location.id

  # Dynamic block to apply multiple permissions from a JSON/Variable input
  dynamic "grant" {
    # Flattening the nested JSON structure: [ { grants: [ {principal, privileges} ] } ]
    # This allows a single resource to manage all users (Principals) and their rights (Privileges)
    for_each = flatten([
      for loc in var.external_location_grants : [
        for g in loc.grants : g
      ]
    ])
    content {
      principal  = grant.value.principal
      privileges = grant.value.privileges
    }
  }
}