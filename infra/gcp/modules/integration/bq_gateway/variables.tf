variable "environment" { type = string }
variable "region" {
  description = "AWS region of the transit VPC (must match the Databricks serverless region)."
  type        = string
}
variable "vpc_id" {
  description = "GCP's own AWS transit VPC (10.11.0.0/16) — not Azure's, which is live."
  type        = string
}
variable "vpc_cidr" {
  description = "That VPC's CIDR. The gateway SG admits 443 from it: NLB health checks and PrivateLink traffic both arrive from inside the VPC."
  type        = string
}
variable "subnet_ids" {
  description = "Private subnets for the NLB and the Fargate task."
  type        = list(string)
}
variable "ecr_repo_name" {
  description = "ECR repository holding the bq-gateway image (created in the network layer, pushed by CI before this layer applies)."
  type        = string
}
variable "private_api_vip_ips" {
  description = "The private.googleapis.com addresses (199.36.153.8-11). The gateway reaches them by IP across the VPN; no DNS is on this path."
  type        = list(string)
}
variable "databricks_serverless_privatelink_account_id" {
  description = "Databricks' serverless-PrivateLink AWS account — the only principal allowed into the endpoint service."
  type        = string
}
