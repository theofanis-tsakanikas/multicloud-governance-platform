# GCP integration — the cross-cloud plumbing, and nothing else.
#
# In PUBLIC mode this layer creates NOTHING, exactly like its AWS and Azure counterparts.
# Databricks reaches BigQuery over Google's public API endpoints; there is no tunnel to dig and no
# gateway to stand up. An apply that finishes in seconds with zero resources is the expected
# behaviour here, not a failure.
#
# In PRIVATE mode it builds the third and last transit hub:
#
#   vpn_bridge   the IPsec tunnel from GCP's own AWS transit VPC (10.11.0.0/16) to the GCP VPC
#   bq_gateway   an HAProxy TCP passthrough on Fargate, fronted by an NLB and a PrivateLink
#                service, carrying :443 across that tunnel to Google's private API VIP
#   bq_ncc_rule  the Databricks half — route bigquery / bigquerystorage / oauth2 .googleapis.com
#                through that PrivateLink service instead of out to the internet
#
# BigQuery is not a database sitting in a VPC, so there is nothing to put a private endpoint in
# front of; and Databricks serverless lives in an AWS account, so it could not create a GCP
# endpoint even if there were. The hub is what bridges those two facts — exactly as it does for
# Azure SQL, and for the same reason.
#
# The old dns_bridge is gone. Nothing on this path resolves a name: the gateway dials the VIP by
# address, and the SNI the Databricks client sends is what Google's frontend routes on.

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "vpn_bridge" {
  for_each = local.private_mode
  source   = "./vpn_bridge"

  aws_vpn_gw_id  = var.aws_vpn_gw_id
  gcp_vpc_id     = var.gcp_vpc_id
  gcp_vpn_gw_id  = var.gcp_vpn_gw_id
  gcp_vpn_gw_ips = var.gcp_vpn_gw_ips
  location       = var.location
  project_id     = var.project_id
}

# The AWS end of the hub. It reaches the VIP by address across the tunnel, so it needs the tunnel
# to exist — though not for BGP to have converged, which Terraform cannot wait for anyway.
module "bq_gateway" {
  for_each = local.private_mode
  source   = "./bq_gateway"

  environment                                  = var.environment
  region                                       = var.region
  vpc_id                                       = var.transit_vpc_id
  vpc_cidr                                     = var.transit_vpc_cidr
  subnet_ids                                   = var.transit_subnet_ids
  ecr_repo_name                                = var.ecr_repo_name
  private_api_vip_ips                          = var.private_api_vip_ips
  databricks_serverless_privatelink_account_id = var.databricks_serverless_privatelink_account_id

  depends_on = [module.vpn_bridge]
}

# The endpoint service exists the moment the NLB is registered, but Databricks takes a beat to see
# it by name. The RDS and Azure hubs both needed this pause.
resource "time_sleep" "gateway_ready" {
  for_each        = local.private_mode
  depends_on      = [module.bq_gateway]
  create_duration = "60s"
}

module "bq_ncc_rule" {
  for_each              = local.private_mode
  source                = "./bq_ncc_rule"
  ncc_id                = var.ncc_id
  endpoint_service_name = module.bq_gateway["enabled"].endpoint_service_name
  domain_names          = var.google_api_domains

  providers = {
    databricks = databricks.account
  }

  depends_on = [time_sleep.gateway_ready]
}

# Creating the rule is not the same as the endpoint being usable — Databricks provisions its side
# over some minutes. dbx_bq_grants, two layers later, is what would otherwise discover this, by
# querying BigQuery and failing with an error that mentions none of it.
resource "time_sleep" "ncc_endpoint_ready" {
  for_each        = local.private_mode
  depends_on      = [module.bq_ncc_rule]
  create_duration = "180s"
}
