output "rds_hostname" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.sales_db.address
}

output "db_instance_id" {
  description = "The ID of the RDS instance"
  value       = aws_db_instance.sales_db.identifier
}

