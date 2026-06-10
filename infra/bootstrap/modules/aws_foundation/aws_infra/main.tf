data "aws_caller_identity" "current" {}

locals {
  # Unity Catalog's master role in the Databricks-owned AWS account. It assumes
  # the metastore data-access role below to read/write the metastore root bucket.
  uc_master_role_arn = "arn:aws:iam::${var.dbx_aws_account_id}:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"

  # Constructed up front so the role's trust and inline policies can reference
  # the role itself (Databricks requires the data-access role to be self-assuming).
  metastore_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.metastore_iam_role_name}"
}

# ─── Unity Catalog metastore root storage ────────────────────────────────────

resource "aws_s3_bucket" "unity_metastore" {
  bucket        = var.metastore_bucket_name
  force_destroy = true

  tags = {
    Name        = "Unity Catalog metastore root"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "unity_metastore" {
  bucket                  = aws_s3_bucket.unity_metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "unity_metastore" {
  bucket = aws_s3_bucket.unity_metastore.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "unity_metastore" {
  bucket = aws_s3_bucket.unity_metastore.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ─── Metastore data-access role (assumed by Unity Catalog) ──────────────────

resource "aws_iam_role" "metastore_data_access" {
  name = var.metastore_iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "UnityCatalogAssumeRole"
      Effect = "Allow"
      Principal = {
        AWS = [local.uc_master_role_arn, local.metastore_role_arn]
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = { "sts:ExternalId" = var.dbx_account_id }
      }
    }]
  })

  tags = { Environment = var.environment }
}

resource "aws_iam_role_policy" "metastore_data_access" {
  name = "${var.metastore_iam_role_name}-policy"
  role = aws_iam_role.metastore_data_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MetastoreRootBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration"
        ]
        Resource = [
          aws_s3_bucket.unity_metastore.arn,
          "${aws_s3_bucket.unity_metastore.arn}/*"
        ]
      },
      {
        Sid      = "SelfAssumeForCredentialVending"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.metastore_role_arn
      }
    ]
  })
}

# ─── Cross-account role (assumed by the Databricks control plane) ───────────

resource "aws_iam_role" "cross_account" {
  name = var.cross_account_role_name

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

  tags = { Environment = var.environment }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "${var.cross_account_role_name}-policy"
  role   = aws_iam_role.cross_account.id
  policy = file("${path.module}/policies/cross_account_policy.json")
}
