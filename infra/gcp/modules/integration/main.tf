# GCP integration — the cross-cloud plumbing, and nothing else.
#
# In PUBLIC mode this layer creates NOTHING, exactly like its AWS and Azure
# counterparts. Databricks reaches BigQuery over Google's own API endpoints; there
# is no tunnel to dig and no private DNS to bridge.
#
# In PRIVATE mode it builds the HA VPN between the AWS Databricks VPC and the GCP
# VPC (vpn_bridge), and the Route53 <-> Cloud DNS bridge that lets the workspace
# resolve restricted.googleapis.com across it (dns_bridge).

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "vpn_bridge" {
  for_each = local.private_mode
  source   = "./vpn_bridge"

  aws_vpn_gw_id     = var.aws_vpn_gw_id
  databricks_vpc_id = var.databricks_vpc_id
  gcp_vpc_id        = var.gcp_vpc_id
  gcp_vpn_gw_id     = var.gcp_vpn_gw_id
  gcp_vpn_gw_ips    = var.gcp_vpn_gw_ips
  location          = var.location
  project_id        = var.project_id
}

module "dns_bridge" {
  for_each = local.private_mode
  source   = "./dns_bridge"

  databricks_vpc_id = var.databricks_vpc_id
}
