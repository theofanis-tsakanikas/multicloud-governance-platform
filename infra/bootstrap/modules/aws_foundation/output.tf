
output "metastore_s3_bucket_arn" {
  description = "The ARN of the S3 bucket used for Metastore Root Storage"
  value       = aws_s3_bucket.unity_metastore.arn
}

output "bucket_name" {
  description = "The name of the S3 bucket used for Metastore Root Storage"
  value       = aws_s3_bucket.unity_metastore.id
}

output "metastore_iam_role_arn" {
  description = "The ARN of the IAM role used for Metastore access"
  value       = aws_iam_role.metastore_data_access.arn
}

output "cross_account_role_arn" {
  description = "The ARN of the cross account role used for the dbx workspace"
  value       = aws_iam_role.cross_account.arn
}


