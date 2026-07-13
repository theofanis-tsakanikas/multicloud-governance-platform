# The key policy. Checkov CKV2_AWS_64 flagged its absence, and the absence was real.
#
# A KMS key with no policy falls back to a default that grants the account root full control — which
# is not a hole in the sense that a stranger can use it, but it is a key whose blast radius is
# "anyone who ever gets an IAM principal in this account". The policy below says the same thing the
# default says, and says it *on purpose*: this is the account that owns the key, and IAM decides the
# rest. The value is not that it changes who can use the key today; it is that the next person to
# widen it has to write down that they did.
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "secrets_key" {
  statement {
    sid    = "AccountRootOwnsTheKeyAndIAMDecidesTheRest"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

# 1. Creation of KMS Key for encrypting secrets
resource "aws_kms_key" "secrets_key" {
  description             = "KMS key for encrypting Databricks platform secrets"
  deletion_window_in_days = var.kms_deletion_window
  # Best practice: rotate keys automatically every year
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.secrets_key.json

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