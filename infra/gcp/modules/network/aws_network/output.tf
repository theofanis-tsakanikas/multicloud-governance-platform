output "vpc_id" {
  description = "The ID of the newly created VPC."
  value       = aws_vpc.databricks_vpc.id
}

output "private_subnet_ids" {
  description = "A list of IDs for the private subnets where Databricks clusters will be deployed."
  value       = [for s in aws_subnet.private_subnets : s.id]
}

output "security_group_id" {
  description = "The ID of the security group governing internal and external cluster traffic."
  value       = aws_security_group.databricks_sg.id
}

output "aws_vpn_gw_id" {
  description = "The ID of the AWS VPN Gateway for cross-cloud connectivity with Azure."
  value       = aws_vpn_gateway.vpn_gw.id
}

output "route_table_id" {
  description = "The ID of the main private route table."
  value       = aws_route_table.private.id
}
output "ecr_repo_name" {
  description = "ECR repo holding the bq-gateway image; CI pushes to it before integration applies."
  value       = aws_ecr_repository.bq_gateway.name
}
