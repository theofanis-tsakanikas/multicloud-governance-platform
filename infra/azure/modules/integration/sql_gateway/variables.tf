variable "environment" {
  description = "dev | prod — names the cluster, NLB, roles, log group."
  type        = string
}

variable "region" {
  description = "AWS region the gateway VPC lives in (must match the Databricks serverless region)."
  type        = string
}

variable "vpc_id" {
  description = "The AWS VPC that network/aws_network builds for the tunnel (10.10.0.0/16)."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets of that VPC — where the NLB and the Fargate task run."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group for the Fargate task (aws_network's databricks_sg: self + egress)."
  type        = string
}

variable "sql_server_fqdn" {
  description = "Azure SQL FQDN, e.g. sql-federation-master-abcd.database.windows.net. HAProxy forwards to it across the VPN; the NCC rule advertises it as the private domain."
  type        = string
}

variable "ecr_repo_name" {
  description = "ECR repository holding the sql-gateway image (created in the network layer, pushed by CI before this layer applies)."
  type        = string
}

variable "databricks_serverless_privatelink_account_id" {
  description = "Databricks' serverless-PrivateLink AWS account — the only principal allowed into the endpoint service."
  type        = string
}
