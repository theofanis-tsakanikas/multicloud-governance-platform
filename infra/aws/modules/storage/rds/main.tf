module "rds" {
  source                 = "./_components/rds"
  db_instance_identifier = var.db_instance_identifier
  allocated_storage      = var.allocated_storage
  db_engine              = var.db_engine
  engine_version         = var.engine_version
  db_instance_class      = var.db_instance_class
  db_name                = var.db_name
  rds_username           = var.rds_username
  password               = var.password
  db_subnet_group_name   = var.db_subnet_group_name
  rds_security_group_id  = var.rds_security_group_id
  is_private_connection  = var.is_private_connection
}
