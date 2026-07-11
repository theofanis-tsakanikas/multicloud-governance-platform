# NCC private-endpoint rule for the BigQuery transit gateway — the Databricks-side half.
#
# The third of three. It tells serverless compute: to reach these Google API hosts, do not go out
# to the internet — go through a private endpoint into that PrivateLink service, which is the
# gateway that carries them across the VPN to Google's private API VIP.
#
# Three domains, one rule, one backend. BigQuery federation needs all three and no fewer:
#
#   bigquery.googleapis.com          the jobs and query API
#   bigquerystorage.googleapis.com   the Storage Read API — this is where the rows actually come from
#   oauth2.googleapis.com            the service-account key is exchanged for a token here, and
#                                    without it the connector cannot authenticate at all
#
# That last one is why this path uses private.googleapis.com and not restricted.googleapis.com:
# the restricted VIP fronts only APIs that support VPC Service Controls, and oauth2 is not among
# them. A private path that cannot authenticate is not a private path.
#
# account_id is deliberately not set: the provider version this layer resolves makes it computed
# and inherits it from the databricks.account provider config (the Azure rule learned this the
# hard way).
resource "databricks_mws_ncc_private_endpoint_rule" "bq_rule" {
  network_connectivity_config_id = var.ncc_id
  endpoint_service               = var.endpoint_service_name
  domain_names                   = var.domain_names
}
