locals {
  master_uc_arn = "arn:aws:iam::${var.dbx_aws_account_id}:role/unity-catalog-prod-UCMasterRole-14S5ZJVKOTYTL"
  self_role_arn = "arn:aws:iam::${var.aws_account_id}:role/${var.iam_role_name}"
  private_mode  = var.is_private_connection ? { "enabled" = true } : {}
}

# Trust policy — single-phase: both Databricks UC Master and self-assume included from day 1.
# External ID = aws_account_id (static, predictable, never changes).
data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = [
        local.master_uc_arn,
        local.self_role_arn,
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.aws_account_id]
    }
  }
}

resource "aws_iam_role" "databricks_role" {
  name                  = var.iam_role_name
  assume_role_policy    = data.aws_iam_policy_document.trust_policy.json
  force_detach_policies = true

  tags = { Environment = var.environment }
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    sid       = "BucketLevel"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads"]
    resources = [var.data_bucket_arn]
  }

  statement {
    sid       = "ObjectLevel"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListMultipartUploadParts", "s3:AbortMultipartUpload"]
    resources = ["${var.data_bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [local.self_role_arn]
  }
}

resource "aws_iam_policy" "s3_access" {
  name   = "databricks-${var.environment}-s3-access"
  policy = data.aws_iam_policy_document.s3_access.json
}

data "aws_iam_policy_document" "managed_file_events" {
  statement {
    sid    = "ManagedFileEventsSetup"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification", "s3:PutBucketNotification",
      "sns:ListSubscriptionsByTopic", "sns:GetTopicAttributes", "sns:SetTopicAttributes",
      "sns:CreateTopic", "sns:TagResource", "sns:Publish", "sns:Subscribe",
      "sqs:CreateQueue", "sqs:DeleteMessage", "sqs:ReceiveMessage", "sqs:SendMessage",
      "sqs:GetQueueUrl", "sqs:GetQueueAttributes", "sqs:SetQueueAttributes",
      "sqs:TagQueue", "sqs:ChangeMessageVisibility", "sqs:PurgeQueue",
    ]
    resources = [var.data_bucket_arn, "arn:aws:sqs:*:*:csms-*", "arn:aws:sns:*:*:csms-*"]
  }

  statement {
    sid       = "ManagedFileEventsList"
    effect    = "Allow"
    actions   = ["sqs:ListQueues", "sqs:ListQueueTags", "sns:ListTopics"]
    resources = ["arn:aws:sqs:*:*:csms-*", "arn:aws:sns:*:*:csms-*"]
  }

  statement {
    sid       = "ManagedFileEventsTeardown"
    effect    = "Allow"
    actions   = ["sns:Unsubscribe", "sns:DeleteTopic", "sqs:DeleteQueue"]
    resources = ["arn:aws:sqs:*:*:csms-*", "arn:aws:sns:*:*:csms-*"]
  }
}

resource "aws_iam_policy" "managed_file_events" {
  name   = "databricks-managed-file-events-policy"
  policy = data.aws_iam_policy_document.managed_file_events.json
}

data "aws_iam_policy_document" "rds_secrets_access" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.rds_secret_arn]
  }
}

resource "aws_iam_policy" "rds_secrets" {
  name   = "databricks-${var.environment}-rds-secrets"
  policy = data.aws_iam_policy_document.rds_secrets_access.json
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.databricks_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_role_policy_attachment" "file_events" {
  role       = aws_iam_role.databricks_role.name
  policy_arn = aws_iam_policy.managed_file_events.arn
}

resource "aws_iam_role_policy_attachment" "rds_secrets" {
  role       = aws_iam_role.databricks_role.name
  policy_arn = aws_iam_policy.rds_secrets.arn
}

# ── Private-mode only: RDS Proxy role ────────────────────────────────────────

resource "aws_iam_role" "proxy_role" {
  for_each = local.private_mode
  name     = "rds-proxy-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "rds.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "proxy_policy" {
  for_each = local.private_mode
  name     = "rds-proxy-secrets-policy"
  role     = aws_iam_role.proxy_role["enabled"].id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = [var.rds_secret_arn] }]
  })
}

# ── Private-mode only: ECS Task Execution role ────────────────────────────────

resource "aws_iam_role" "ecs_exec_role" {
  for_each = local.private_mode
  name     = "ecs-exec-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec" {
  for_each   = local.private_mode
  role       = aws_iam_role.ecs_exec_role["enabled"].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_secrets_kms" {
  for_each = local.private_mode
  name     = "ecs-secrets-kms-access"
  role     = aws_iam_role.ecs_exec_role["enabled"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [var.rds_secret_arn] },
      { Effect = "Allow", Action = ["kms:Decrypt"], Resource = ["*"] },
      { Effect = "Allow", Action = ["ecr:CreateRepository", "ecr:BatchImportUpstreamImage"], Resource = "*" },
    ]
  })
}
