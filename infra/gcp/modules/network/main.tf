# GCP network — the VPC, and (private mode only) the AWS side of the tunnel.
#
#   public  : VPC + subnet + firewall rule. All free.
#   private : the above, plus the HA VPN gateway and the restricted-googleapis
#             private DNS zone (gated inside gcp_network), plus an AWS VPC with a
#             NAT gateway and a VPN gateway (gated here).
#
# In public mode the platform uses the serverless workspace created during the GCP
# bootstrap, so it needs no AWS-side VPC at all.

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "gcp_network" {
  source = "./gcp_network"

  project_id            = var.project_id
  location              = var.location
  network_name          = var.network_name
  subnetwork_name       = var.subnetwork_name
  gcp_subnet_cidr       = var.gcp_subnet_cidr[0] # the component takes one range; config holds a list
  databricks_vpc_cidr   = var.databricks_vpc_cidr
  vpn_gw_name           = var.vpn_gw_name
  is_private_connection = var.is_private_connection
}

module "aws_network" {
  for_each = local.private_mode
  source   = "./aws_network"

  region              = var.region
  databricks_vpc_cidr = var.databricks_vpc_cidr
  gcp_vpc_cidr        = var.gcp_vpc_cidr
  databricks_subnets  = var.databricks_subnets
}
