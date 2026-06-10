# Resource to define how Databricks connects to AWS storage
resource "databricks_storage_credential" "creds" {
  # Dynamic naming using environment and unique deployment ID
  name = "aws_data_storage_${var.environment}_${var.deployment_id_aws}"

  # AWS-specific authentication using an IAM Role ARN
  aws_iam_role {
    role_arn = var.iam_role_arn
  }

  # Lifecycle rules to manage resource deletion behavior
  lifecycle {
    # Set to false to allow Terraform to destroy/recreate this credential
    prevent_destroy = false
  }
}