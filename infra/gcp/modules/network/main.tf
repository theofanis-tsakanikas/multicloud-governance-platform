# GCP network — the VPC, and (private mode only) the AWS side of the tunnel.
#
#   public  : VPC + subnet + firewall rule. All free, and nothing else.
#   private : the above, plus the HA VPN gateway and the route that hands Google's private API VIP
#             to Google (both gated inside gcp_network), plus GCP's own AWS transit VPC — with a
#             NAT gateway, a VPN gateway, and the ECR repo the BigQuery gateway image is pushed to.
#
# The transit VPC is 10.11.0.0/16. It cannot be 10.10.0.0/16: that is Azure's hub, it is live right
# now carrying Azure SQL, and nothing in this file may touch it.
#
# In public mode the platform uses the serverless workspace created during the GCP bootstrap, and
# needs no AWS-side VPC at all.

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "gcp_network" {
  source = "./gcp_network"

  project_id      = var.project_id
  location        = var.location
  network_name    = var.network_name
  subnetwork_name = var.subnetwork_name
  gcp_subnet_cidr = var.gcp_subnet_cidr[0] # the component takes one range; config holds a list

  # The firewall admits the transit VPC — the network the gateway actually dials from.
  databricks_vpc_cidr   = var.transit_vpc_cidr
  vpn_gw_name           = var.vpn_gw_name
  is_private_connection = var.is_private_connection
  private_api_vip_cidr  = var.private_api_vip_cidr
}

module "aws_network" {
  for_each = local.private_mode
  source   = "./aws_network"

  region           = var.region
  transit_vpc_cidr = var.transit_vpc_cidr
  transit_subnets  = var.transit_subnets
  transit_nat_cidr = var.transit_nat_cidr
  ecr_repo_name    = var.ecr_repo_name

  # Route destinations installed toward the VPN gateway: the GCP VPC, and Google's private API VIP.
  gcp_vpc_cidr = var.gcp_vpc_cidr
}
