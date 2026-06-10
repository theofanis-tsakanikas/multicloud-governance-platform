

module "aws_rds_databricks_connection" {
  source = "../../../../../infra/aws/modules/data_platform/dbx_rds_connector"

  rds_hostname        = var.rds_hostname
  rds_port            = var.rds_port
  rds_username        = var.rds_username
  password            = var.password
  rds_connection_name = var.rds_connection_name
}