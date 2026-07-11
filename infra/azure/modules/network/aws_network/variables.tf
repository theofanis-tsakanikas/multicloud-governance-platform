variable "region" {
  description = "The AWS region where the infrastructure will be deployed."
  type        = string
}

variable "databricks_vpc_cidr" {
  description = "The CIDR block for the Databricks Classic VPC."
  type        = string
}

variable "azure_vnet_cidr" {
  description = "The CIDR block of the Azure Virtual Network for VPN routing purposes."
  type        = list(string)
}

variable "databricks_subnets" {
  description = "Map of subnet names to CIDR blocks"
  type        = map(string)
}
variable "ecr_repo_name" {
  description = "ECR repository name for the SQL transit gateway image."
  type        = string
  default     = "sql-gateway"
}
