# 1. Creation of KMS Key for encrypting secrets
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for encrypting Databricks platform secrets"
  deletion_window_in_days = var.kms_deletion_window
  # Best practice: rotate keys automatically every year
  enable_key_rotation = true

  tags = {
    Name        = "dbx-secrets-kms-${var.environment}"
    Environment = var.environment
  }
}

# 2. Alias for the KMS Key for easier identification in the Console
resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/dbx-secrets-${var.environment}"
  target_key_id = aws_kms_key.secrets_key.key_id
}

# 3. Creation of the AWS Secrets Manager Secret container
resource "aws_secretsmanager_secret" "dbx_spn_credentials" {
  # Uses a dynamic name via variables for logical path organization
  name        = "${var.secret_base_path}/${var.environment}/spn_credentials"
  description = "Databricks Service Principal credentials for automation"
  # Attaches the custom KMS key for encryption at rest
  kms_key_id = aws_kms_key.secrets_key.arn

  # Uses a variable for the recovery window (e.g., 0 for dev, 30 for prod)
  recovery_window_in_days = var.secret_recovery_window

  tags = {
    Environment = var.environment
  }
}