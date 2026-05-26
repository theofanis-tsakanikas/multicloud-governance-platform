output "ecr_repo_name" {
  value       = aws_ecr_repository.pgbouncer.name
  description = "The name of the ECR repository (π.χ. pgbouncer-gateway)"
}
