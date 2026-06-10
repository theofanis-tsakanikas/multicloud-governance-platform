# RDS Instance
resource "aws_db_instance" "sales_db" {
  identifier        = var.db_instance_identifier
  allocated_storage = var.allocated_storage
  engine            = var.db_engine
  engine_version    = var.engine_version
  instance_class    = var.db_instance_class
  db_name           = var.db_name
  username          = var.rds_username
  password          = var.password

  # Integration with outputs from the network module/file
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]

  # Logic: Determine internet reachability based on the connection type
  publicly_accessible = !var.is_private_connection
  # Set to true for easier automated cleanup (use false for Production)
  skip_final_snapshot = true
}