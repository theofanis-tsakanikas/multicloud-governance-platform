output "vpc_id" { value = module.rds_network.vpc_id }
output "subnet_ids" { value = module.rds_network.subnet_ids }
output "db_subnet_group_name" { value = module.rds_network.db_subnet_group_name }
output "rds_security_group_id" { value = module.rds_network.rds_security_group_id }
output "ecs_security_group_id" { value = module.rds_network.ecs_security_group_id }
