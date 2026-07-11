# NCC private-endpoint rule for the Azure SQL transit gateway — the Databricks-side half.
#
# The twin of aws/.../aws_rds_ncc_rule, and identical in shape: a Databricks account-level rule
# that tells serverless compute "to reach this domain, use a private endpoint into that service."
# The only difference is the domain — here it is the real Azure SQL FQDN, so the existing
# connector needs no private-mode override: it already connects by that name, and this rule makes
# that name resolve to the PrivateLink endpoint that fronts the transit gateway.
resource "databricks_mws_ncc_private_endpoint_rule" "sql_rule" {
  account_id                     = var.databricks_account_id
  network_connectivity_config_id = var.ncc_id
  endpoint_service               = var.endpoint_service_name
  domain_names                   = [var.sql_server_fqdn]
}
