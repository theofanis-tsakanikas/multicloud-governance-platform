# Azure integration — the cross-cloud plumbing, and nothing else.
#
# In PUBLIC mode this layer creates NOTHING. Databricks reaches Azure SQL over its
# public endpoint (guarded by a firewall rule in the storage layer), so there is no
# private endpoint to build and no tunnel to dig. `terragrunt apply` on this layer
# completing in seconds with zero resources is the expected behaviour, exactly as
# the AWS integration layer behaves in public mode.
#
# In PRIVATE mode it builds both halves of the path:
#
#   private_endpoint  — a Private Link interface for the SQL server inside the
#                       endpoint subnet, plus the privatelink DNS zone.
#   aws_az_vpn_conn   — the Site-to-Site VPN joining the AWS Databricks VPC to the
#                       Azure VNet, so the workspace can resolve and reach that
#                       private IP.
#
# Both are gated by the same empty-map trick the AWS layers use, so the plan is
# literally empty in public mode rather than "created then ignored".

locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

# The IPsec pre-shared key is generated, never configured: it is a secret with no
# reason to exist outside the two gateways, so nothing has to store or rotate it.
resource "random_password" "vpn_psk" {
  for_each = local.private_mode
  length   = 32
  special  = false
}

module "private_endpoint" {
  for_each = local.private_mode
  source   = "./private_endpoint"

  resource_group_name = var.resource_group_name
  location            = var.location
  sql_server_name     = var.sql_server_name
  sql_server_id       = var.sql_server_id
  vnet_id             = var.vnet_id
  endpoint_subnet_id  = var.endpoint_subnet_id
}

module "aws_az_vpn_conn" {
  for_each = local.private_mode
  source   = "./aws_az_vpn_conn"

  aws_vpn_gw_id       = var.aws_vpn_gw_id
  databricks_vpc_cidr = var.databricks_vpc_cidr
  azure_vpn_public_ip = var.azure_vpn_public_ip
  azure_vpn_gw_id     = var.azure_vpn_gw_id
  azure_vnet_cidr     = var.azure_vnet_cidr
  location            = var.location
  resource_group_name = var.resource_group_name
  shared_key          = coalesce(var.vpn_shared_key, random_password.vpn_psk["enabled"].result)
  sql_server_fqdn     = var.sql_server_fqdn
  vpc_id              = var.vpc_id
  private_ip_address  = module.private_endpoint["enabled"].private_ip_address
}

# ── The AWS end of the transit hub ────────────────────────────────────────────────────────────
# An HAProxy gateway on Fargate, fronted by an NLB and a PrivateLink service, that carries TCP
# 1433 from Databricks serverless across the VPN (built just above) to the Azure private endpoint.
# It resolves the Azure SQL FQDN through the Route53 zone aws_az_vpn_conn creates, so it depends
# on that module having run.
module "sql_gateway" {
  for_each = local.private_mode
  source   = "./sql_gateway"

  environment                                  = var.environment
  region                                       = var.region
  vpc_id                                       = var.vpc_id
  subnet_ids                                   = var.subnet_ids
  security_group_id                            = var.security_group_id
  sql_server_fqdn                              = var.sql_server_fqdn
  ecr_repo_name                                = var.ecr_repo_name
  databricks_serverless_privatelink_account_id = var.databricks_serverless_privatelink_account_id

  depends_on = [module.aws_az_vpn_conn]
}

# The endpoint service exists the moment the NLB is registered, but Databricks' provisioning of
# its interface endpoint into it lags — same as the RDS side. Give it a beat before the NCC rule
# references the service by name.
resource "time_sleep" "gateway_ready" {
  for_each        = local.private_mode
  depends_on      = [module.sql_gateway]
  create_duration = "60s"
}

# ── The Databricks-side half: route the Azure SQL FQDN through the gateway's PrivateLink ───────
module "sql_ncc_rule" {
  for_each              = local.private_mode
  source                = "./sql_ncc_rule"
  ncc_id                = var.ncc_id
  endpoint_service_name = module.sql_gateway["enabled"].endpoint_service_name
  sql_server_fqdn       = var.sql_server_fqdn
  databricks_account_id = var.dbx_account_id

  providers = {
    databricks = databricks.account
  }

  depends_on = [time_sleep.gateway_ready]
}

# Creating the NCC rule is not the same as the private endpoint being usable — Databricks takes a
# few minutes to establish it. dbx_mssql_grants, three layers later, warms the foreign catalog by
# querying Azure SQL; without this wait it would fail with an error naming none of this.
resource "time_sleep" "ncc_endpoint_ready" {
  for_each        = local.private_mode
  depends_on      = [module.sql_ncc_rule]
  create_duration = "180s"
}
