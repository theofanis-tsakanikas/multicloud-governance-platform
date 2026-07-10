locals {
  private_mode = var.is_private_connection ? { "enabled" = true } : {}
}

module "ecr_registry" {
  for_each      = local.private_mode
  source        = "./_components/ecr_registry"
  ecr_repo_name = var.ecr_repo_name
}

module "s3_buckets" {
  source        = "./_components/s3_buckets"
  environment   = var.environment
  bucket_name   = var.bucket_name
  force_destroy = var.force_destroy
}
