output "endpoint_service_name" {
  description = "GIVE THIS TO DATABRICKS: The VPC Endpoint Service name"
  value       = aws_vpc_endpoint_service.rds_ncc_service.service_name
}

output "endpoint_service_id" {
  value = aws_vpc_endpoint_service.rds_ncc_service.id
}

output "custom_db_hostname" {
  description = "The friendly DNS name for your database"
  value       = aws_route53_record.rds_dns.fqdn
}

output "nlb_dns_name" {
  description = "The auto-generated DNS of the NLB"
  value       = aws_lb.nlb.dns_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "rds_custom_dns_name" {
  value = aws_route53_record.rds_dns.name
}

output "rds_proxy_endpoint" {
  description = "The DNS endpoint of the RDS Proxy"
  value       = aws_db_proxy.rds_proxy.endpoint
}