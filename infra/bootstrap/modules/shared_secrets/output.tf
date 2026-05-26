output "kms_key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.secrets_key.arn
}

output "spn_secret_arn" {
  description = "The ARN of the Secret"
  value       = aws_secretsmanager_secret.dbx_spn_credentials.arn
}

output "spn_secret_name" {
  description = "The full name/path of the Secret"
  value       = aws_secretsmanager_secret.dbx_spn_credentials.name
}