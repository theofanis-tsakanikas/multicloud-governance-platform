
variable "iam_role_arn" {
  type        = string
  description = "IAM role ARN used by Databricks"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "deployment_id_aws" {
  type = string
}
