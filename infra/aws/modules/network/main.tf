module "rds_network" {
  source                = "./_components/rds_network"
  region                = var.region
  environment           = var.environment
  is_private_connection = var.is_private_connection
  rds_vpc_cidr          = var.rds_vpc_cidr
  rds_subnets_config    = var.rds_subnets_config
  orch_ip               = var.orch_ip
}
