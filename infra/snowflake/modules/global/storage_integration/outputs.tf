output "iam_user_arn" {
  description = "The IAM user Snowflake minted for this integration. The caller's IAM role must trust it."
  value       = snowflake_storage_integration_aws.this.describe_output[0].iam_user_arn
}

output "external_id" {
  description = "The external id the trust policy must require (echoed back from Snowflake, not assumed)."
  value       = snowflake_storage_integration_aws.this.describe_output[0].external_id
}

output "integration_name" {
  description = "Name to reference from CREATE STAGE."
  value       = snowflake_storage_integration_aws.this.name
}
