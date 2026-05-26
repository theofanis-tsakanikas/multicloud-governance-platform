output "route53_zone_id" {
  description = "The ID of the Route 53 Private Hosted Zone."
  value       = aws_route53_zone.gcp_dns_proxy.zone_id
}

output "route53_zone_name" {
  description = "The name of the DNS zone created in AWS."
  value       = aws_route53_zone.gcp_dns_proxy.name
}

output "restricted_api_ips" {
  description = "The Restricted Google API IPs used for routing."
  value       = aws_route53_record.google_apis_restricted.records
}