output "endpoint_service_name" {
  description = "The VPC Endpoint Service name the NCC private-endpoint rule points at."
  value       = aws_vpc_endpoint_service.bq_ncc_service.service_name
}
