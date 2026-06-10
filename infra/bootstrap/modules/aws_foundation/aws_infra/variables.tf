variable "environment" {
  description = "Environment suffix used for tagging (e.g. dev, prod)."
  type        = string
}

variable "region" {
  description = "AWS region where the foundation resources are created."
  type        = string
}

variable "dbx_aws_account_id" {
  description = "The static AWS account ID owned by Databricks (414351767826)."
  type        = string
}

variable "dbx_account_id" {
  description = "The Databricks account ID (UUID) — used as the sts:ExternalId."
  type        = string
}

variable "metastore_bucket_name" {
  description = "Name of the S3 bucket backing the Unity Catalog metastore root."
  type        = string
}

variable "metastore_iam_role_name" {
  description = "Name of the IAM role Unity Catalog assumes for metastore data access."
  type        = string
}

variable "cross_account_role_name" {
  description = "Name of the cross-account IAM role the Databricks control plane assumes."
  type        = string
}
