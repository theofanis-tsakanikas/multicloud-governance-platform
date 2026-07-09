# The AWS half of the Snowflake storage integration.
#
# Snowflake reads the SAME S3 prefixes Unity Catalog reads — the domain's external
# locations. Neither engine holds a credential: UC assumes `databricks-access-role`
# (security/iam), Snowflake assumes the role below. Two engines, one bucket, one
# governance contract (ADR-0011).
#
# The trust is two-way and would be circular if built naively — Snowflake needs the role
# ARN to create the integration, and the role needs Snowflake's minted IAM user to write
# its trust policy. It is broken by *deriving* the role ARN as a string from the account
# id and a name we choose, so nothing waits on the role resource. Terraform then orders:
#
#   integration (needs the ARN string) -> role (needs the integration's iam_user_arn)

data "aws_caller_identity" "current" {}

locals {
  snowflake_role_name = "snowflake-s3-access-${var.environment}"
  snowflake_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_role_name}"

  # Deterministic, so the trust policy is fully reviewable in a plan rather than
  # appearing only after Snowflake mints a value.
  snowflake_external_id = upper("${var.environment}_${var.domain}_SF")

  # Prefix (no leading/trailing slash) for each of the domain's external locations.
  external_prefixes = [for l in local.ext_locs : trim(l.path, "/")]
}

module "storage_integration" {
  source = "../../../../snowflake/modules/global/storage_integration"

  integration_name  = var.storage_integration_name
  domain            = var.domain
  aws_role_arn      = local.snowflake_role_arn
  external_id       = local.snowflake_external_id
  allowed_locations = [for s in local.external_stages : s.url]
}

data "aws_iam_policy_document" "snowflake_trust" {
  statement {
    sid     = "SnowflakeAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [module.storage_integration.iam_user_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [module.storage_integration.external_id]
    }
  }
}

resource "aws_iam_role" "snowflake" {
  name               = local.snowflake_role_name
  description        = "Assumed by Snowflake's storage integration to read/write the ${var.domain} domain's external locations."
  assume_role_policy = data.aws_iam_policy_document.snowflake_trust.json
}

# Scoped to the domain's external-location prefixes only — never the whole bucket.
data "aws_iam_policy_document" "snowflake_s3" {
  statement {
    sid    = "ObjectAccessWithinDomainPrefixes"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [for p in local.external_prefixes : "arn:aws:s3:::${var.storage_bucket}/${p}/*"]
  }

  statement {
    sid       = "ListOnlyDomainPrefixes"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = ["arn:aws:s3:::${var.storage_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [for p in local.external_prefixes : "${p}/*"]
    }
  }
}

resource "aws_iam_policy" "snowflake_s3" {
  name        = "${local.snowflake_role_name}-policy"
  description = "S3 access for the Snowflake storage integration, scoped to the ${var.domain} external locations."
  policy      = data.aws_iam_policy_document.snowflake_s3.json
}

resource "aws_iam_role_policy_attachment" "snowflake_s3" {
  role       = aws_iam_role.snowflake.name
  policy_arn = aws_iam_policy.snowflake_s3.arn
}
