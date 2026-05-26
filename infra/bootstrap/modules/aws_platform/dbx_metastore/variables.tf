
variable "region" {
  description = "The AWS region where the metastore will be created"
  type        = string
  default     = "eu-central-1"
}

variable "metastore_name" {
  description = "The display name for the Unity Catalog Metastore"
  type        = string
}

variable "metastore_storage_root" {
  description = "The S3 URI for the metastore storage root (e.g., s3://my-bucket/metastore)"
  type        = string
  validation {
    condition     = can(regex("^s3://", var.metastore_storage_root))
    error_message = "The storage_root must be a valid S3 URI starting with 's3://'."
  }
}

variable "metastore_iam_role_arn" {
  description = "The ARN of the IAM role that has access to the metastore S3 bucket"
  type        = string
}

variable "admin_group_name" {
  description = "The name of the Databricks group that will own the metastore"
  type        = string
}

variable "delta_sharing_token_lifetime" {
  description = "Lifetime of Delta Sharing recipient tokens in seconds (0 for infinite)"
  type        = number
}

variable "admin_group_id" {
  description = "The Databricks Group ID (Principal ID) for workspace admins"
  type        = string
}

variable "delta_sharing_name" {
  type        = string
  description = "The unique name for this Metastore in the Delta Sharing ecosystem."
}
