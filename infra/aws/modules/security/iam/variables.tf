variable "environment" {
  type = string
}

variable "aws_account_id" {
  type        = string
  description = "Customer AWS Account ID. Also used as the ExternalId in the Databricks trust policy."
}

variable "dbx_aws_account_id" {
  type        = string
  description = "Databricks AWS Account ID (hosts the Unity Catalog Master Role)"
}

variable "iam_role_name" {
  type = string
}

variable "data_bucket_arn" {
  type = string
}

variable "rds_secret_arn" {
  type = string
}

variable "is_private_connection" {
  type    = bool
  default = false
}
