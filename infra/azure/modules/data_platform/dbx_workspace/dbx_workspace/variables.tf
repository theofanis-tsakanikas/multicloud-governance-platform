variable "dbx_aws_account_id" {
  description = "The static AWS account ID owned by Databricks (414351767826)."
  type        = string
}

variable "dbx_account_id" {
  description = "The Databricks account ID (UUID) — used as the sts:ExternalId."
  type        = string
}

variable "managed_workspace_name" {
  description = "Name of the Databricks workspace; also prefixes the IAM role and root bucket."
  type        = string
}

variable "region" {
  description = "AWS region the workspace is deployed into."
  type        = string
}

variable "vpc_id" {
  description = "ID of the customer-managed VPC for the workspace."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Databricks cluster injection."
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group attached to the Databricks cluster network."
  type        = string
}

variable "metastore_id" {
  description = "ID of the existing Unity Catalog metastore to assign the workspace to."
  type        = string
}
