# Resource to define a Private Endpoint Rule for Network Connectivity Config (NCC)
resource "databricks_mws_ncc_private_endpoint_rule" "rds_rule" {
  # The Databricks Account ID where the NCC resides
  account_id = var.databricks_account_id
  # The ID of the existing Network Connectivity Configuration
  network_connectivity_config_id = var.ncc_id

  # The name of the Endpoint Service created in AWS for the RDS instance
  endpoint_service = var.endpoint_service_name

  # The custom DNS name used to resolve the RDS instance over the private link
  domain_names = [var.rds_custom_dns_name]
}