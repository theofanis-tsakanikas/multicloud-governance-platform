#########################################
# Network Outputs
#########################################
output "vpc_id" {
  description = "The ID of the RDS VPC"
  value       = aws_vpc.rds_vpc.id
}

output "subnet_ids" {
  description = "List of all subnet IDs created"
  value       = [for s in aws_subnet.subnets : s.id]
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}


# 2. SG IDs
output "rds_security_group_id" {
  description = "The ID of the security group for RDS and RDS Proxy"
  value       = aws_security_group.rds_sg.id
}

output "ecs_security_group_id" {
  description = "The ID of the ECS Security Group (if private)"
  value       = var.is_private_connection ? aws_security_group.ecs_sg["enabled"].id : ""
}
