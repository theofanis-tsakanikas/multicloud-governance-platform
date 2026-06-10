# Private (customer-managed VPC) Databricks workspace on AWS, used when
# is_private_connection = true so cross-cloud traffic stays on the private
# backbone instead of the public internet.

data "aws_caller_identity" "current" {}

# ─── Cross-account IAM role assumed by the Databricks control plane ─────────

resource "aws_iam_role" "cross_account" {
  name = "${var.managed_workspace_name}-cross-account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DatabricksControlPlaneAssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.dbx_aws_account_id}:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = { "sts:ExternalId" = var.dbx_account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${var.managed_workspace_name}-cross-account-policy"
  role   = aws_iam_role.cross_account.id
  policy = file("${path.module}/policies/cross_account_policy.json")
}

# IAM is eventually consistent — give the new role time to propagate before
# the Databricks API validates it during credential registration.
resource "time_sleep" "iam_propagation" {
  depends_on      = [aws_iam_role_policy.cross_account]
  create_duration = "30s"
}

resource "databricks_mws_credentials" "this" {
  credentials_name = "${var.managed_workspace_name}-credentials"
  role_arn         = aws_iam_role.cross_account.arn

  depends_on = [time_sleep.iam_propagation]
}

# ─── Workspace root storage ──────────────────────────────────────────────────

resource "aws_s3_bucket" "root_storage" {
  bucket        = "${var.managed_workspace_name}-root-storage"
  force_destroy = true

  tags = { Name = "${var.managed_workspace_name} workspace root storage" }
}

resource "aws_s3_bucket_public_access_block" "root_storage" {
  bucket                  = aws_s3_bucket.root_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "root_storage" {
  bucket = aws_s3_bucket.root_storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "DatabricksRootBucketAccess"
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${var.dbx_aws_account_id}:root"
      }
      Action = [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ]
      Resource = [
        aws_s3_bucket.root_storage.arn,
        "${aws_s3_bucket.root_storage.arn}/*"
      ]
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.root_storage]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.dbx_account_id
  storage_configuration_name = "${var.managed_workspace_name}-storage"
  bucket_name                = aws_s3_bucket.root_storage.bucket
}

# ─── Customer-managed network + workspace ────────────────────────────────────

resource "databricks_mws_networks" "this" {
  account_id         = var.dbx_account_id
  network_name       = "${var.managed_workspace_name}-network"
  vpc_id             = var.vpc_id
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [var.security_group_id]
}

resource "databricks_mws_workspaces" "this" {
  account_id     = var.dbx_account_id
  aws_region     = var.region
  workspace_name = var.managed_workspace_name

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id
}

# Attach the workspace to the existing Unity Catalog metastore.
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}
