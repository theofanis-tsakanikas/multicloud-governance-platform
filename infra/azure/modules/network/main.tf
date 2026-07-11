# Azure network — the VNet, and (private mode only) the AWS side of the tunnel.
#
# The gate is the same one the AWS foundation uses: a map that is empty in public
# mode, so `for_each` produces zero instances. Everything expensive sits behind it.
#
#   public  : VNet + 3 subnets + NSG. Free. Nothing else.
#   private : the above, plus the Azure VPN gateway (gated inside azure_network),
#             plus an AWS VPC with a NAT gateway and a VPN gateway (this module).
#
# The Databricks workspace in public mode is the serverless one created during
# bootstrap, so no AWS-side VPC is needed at all — hence the whole aws_network
# component, NAT gateway included, is private-only.

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "azure_network" {
  source = "./azure_network"

  resource_group_name    = var.resource_group_name
  location               = var.location
  vnet_name              = var.vnet_name
  azure_vnet_cidr        = var.azure_vnet_cidr
  data_subnet_prefix     = var.data_subnet_prefix
  endpoint_subnet_prefix = var.endpoint_subnet_prefix
  gateway_subnet_prefix  = var.gateway_subnet_prefix
  databricks_vpc_cidr    = var.databricks_vpc_cidr
  is_private_connection  = var.is_private_connection
}

module "aws_network" {
  for_each = local.private_mode
  source   = "./aws_network"

  region              = var.region
  databricks_vpc_cidr = var.databricks_vpc_cidr
  azure_vnet_cidr     = var.azure_vnet_cidr
  databricks_subnets  = var.databricks_subnets
  ecr_repo_name       = var.ecr_repo_name
}
