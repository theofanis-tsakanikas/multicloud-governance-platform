output "endpoint_service_name" {
  description = "GIVE THIS TO DATABRICKS: the VPC Endpoint Service name the NCC private-endpoint rule points at."
  value       = aws_vpc_endpoint_service.sql_ncc_service.service_name
}

output "nlb_dns_name" {
  description = "Internal NLB DNS name (diagnostics only; Databricks reaches it via the endpoint service, not this name)."
  value       = aws_lb.nlb.dns_name
}
