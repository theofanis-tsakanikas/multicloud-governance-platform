# 1. Private Hosted Zone in AWS Route 53
resource "aws_route53_zone" "gcp_dns_proxy" {
  name = "googleapis.com"

  vpc {
    vpc_id = var.databricks_vpc_id
  }

  tags = { Name = "gcp-apis-dns-proxy" }
}

# 2. DNS Records for Google APIs (Restricted Range)
resource "aws_route53_record" "google_apis_restricted" {
  zone_id = aws_route53_zone.gcp_dns_proxy.zone_id
  name    = "*.googleapis.com" # Wildcard covering every Google API (BigQuery, Storage, etc.)
  type    = "A"
  ttl     = "300"

  # The IPs of the Restricted Google API
  records = [
    "199.36.153.4",
    "199.36.153.5",
    "199.36.153.6",
    "199.36.153.7"
  ]
}

# Record and for the apex domain (googleapis.com)
resource "aws_route53_record" "google_apis_apex" {
  zone_id = aws_route53_zone.gcp_dns_proxy.zone_id
  name    = "googleapis.com"
  type    = "A"
  ttl     = "300"
  records = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}