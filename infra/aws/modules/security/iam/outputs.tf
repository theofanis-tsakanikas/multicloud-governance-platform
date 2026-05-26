output "iam_role_arn" {
  value = aws_iam_role.databricks_role.arn
}

output "iam_role_name" {
  value = aws_iam_role.databricks_role.name
}

output "proxy_role_arn" {
  value = var.is_private_connection ? aws_iam_role.proxy_role["enabled"].arn : ""
}

output "ecs_role_arn" {
  value = var.is_private_connection ? aws_iam_role.ecs_exec_role["enabled"].arn : ""
}
