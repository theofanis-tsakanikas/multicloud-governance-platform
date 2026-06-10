# Creation of the ECR Repository for container images
resource "aws_ecr_repository" "pgbouncer" {
  # Dynamic repository name based on input variables
  name = var.ecr_repo_name
  # Allows tags to be overwritten (useful for 'latest' or 'dev' tags)
  image_tag_mutability = "MUTABLE"
  # Ensures the repository is removed even if it contains images during a 'terraform destroy'
  force_delete = true
}