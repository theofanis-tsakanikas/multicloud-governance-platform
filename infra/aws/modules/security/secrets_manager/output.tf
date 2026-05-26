output "rds_secret_arn" {
  description = "The ARN of the created secret"
  value       = aws_secretsmanager_secret.db_secret.arn
}

output "secret_id" {
  value = aws_secretsmanager_secret.db_secret.id
}

output "password_name" {
  description = "The name of the created secret"
  value       = aws_secretsmanager_secret.db_secret.name
}
