# --- Common Variables ---
variable "environment" {
  description = "The environment name (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
}

# --- Network Variables ---
variable "vpc_id" {
  description = "The ID of the VPC where the gateway will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for NLB and ECS Service"
  type        = list(string)
}

variable "rds_security_group_id" {
  description = "Security group ID for the RDS Proxy"
  type        = string
}

variable "ecs_security_group_id" {
  description = "Security group ID for the ECS Service"
  type        = string
}

# --- RDS & Authentication Variables ---
variable "db_instance_identifier" {
  description = "The identifier of the RDS instance to proxy"
  type        = string
}

variable "rds_secret_arn" {
  description = "The ARN of the secret in Secrets Manager containing DB credentials"
  type        = string
}

variable "rds_username" {
  description = "The master username for the database"
  type        = string
}

# --- IAM Roles ---
variable "proxy_role_arn" {
  description = "IAM Role ARN for the RDS Proxy to access Secrets Manager"
  type        = string
}

variable "ecs_role_arn" {
  description = "IAM Role ARN for ECS Task Execution and Task Role"
  type        = string
}

# --- Container / ECR Variables ---
variable "ecr_repo_name" {
  description = "The name of the ECR repository for the PgBouncer image"
  type        = string
}

# --- DNS Variables ---
variable "private_dns_zone_name" {
  description = "The name of the private Route53 zone (e.g. platform.local)"
  type        = string
}

variable "rds_custom_dns_name" {
  description = "The custom DNS record for the RDS gateway (e.g. rds-private.platform.local)"
  type        = string
}
variable "rds_hostname" {
  description = "The RDS instance endpoint. The gateway itself goes through the proxy; this is for the image's one-shot roles, which must reach the database directly from inside the VPC because nothing outside it can."
  type        = string
}

variable "db_name" {
  description = "Database the one-shot roles connect to."
  type        = string
}

variable "databricks_serverless_privatelink_account_id" {
  description = "Databricks' SERVERLESS PrivateLink account (565502421330) — not the workspace cross-account one. Its private-connectivity-role-<region> is the single principal allowed to put an endpoint into this service, and Databricks validates that exact ARN is on the allow-list before it will even try."
  type        = string
}
