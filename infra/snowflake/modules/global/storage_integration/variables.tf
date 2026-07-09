variable "integration_name" {
  description = "Name of the Snowflake storage integration."
  type        = string
}

variable "domain" {
  description = "Domain this integration serves (used in the comment)."
  type        = string
}

variable "aws_role_arn" {
  description = "ARN of the IAM role Snowflake assumes. Derived as a string by the caller, so this module never waits on the role to exist."
  type        = string
}

variable "external_id" {
  description = "sts:ExternalId Snowflake presents when assuming the role. Caller-supplied so the trust policy is deterministic in a plan."
  type        = string
}

variable "allowed_locations" {
  description = "S3 URLs (s3://bucket/prefix/) the integration may access — the domain's external locations."
  type        = list(string)
}
