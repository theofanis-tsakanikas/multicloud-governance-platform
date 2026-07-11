output "api_integration_name" {
  description = "Name to select in Snowsight → Workspaces → Create Workspace → From Git repository."
  value       = var.api_integration_name
}

output "repository_fqn" {
  description = "Fully-qualified GIT REPOSITORY object. `ALTER GIT REPOSITORY <this> FETCH` then `LS @<this>/branches/main/` proves the integration works."
  value       = "${var.database}.${var.schema}.${var.repository_name}"
}

output "repo_origin" {
  description = "The clone URL a Git-backed Workspace should be pointed at."
  value       = var.repo_origin
}
