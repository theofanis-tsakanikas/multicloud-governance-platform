output "data_bucket_name" {
  value = module.s3_buckets.data_bucket_name
}

output "data_bucket_arn" {
  value = module.s3_buckets.data_bucket_arn
}

output "data_bucket_id" {
  value = module.s3_buckets.data_bucket_id
}

output "ecr_repo_name" {
  value = var.is_private_connection ? module.ecr_registry["enabled"].ecr_repo_name : ""
}
