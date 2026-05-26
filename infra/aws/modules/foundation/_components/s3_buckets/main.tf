# Main S3 Bucket definition
resource "aws_s3_bucket" "data_bucket" {
  # Name of the bucket passed from the orchestrator variables
  bucket = var.bucket_name

  # Resource tagging for cost tracking and management
  tags = {
    Name        = "Data Bucket"
    Environment = var.environment
    Layer       = "raw"
  }
}

# Strict Public Access Block configuration (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket                  = aws_s3_bucket.data_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Data Versioning to prevent accidental deletions
resource "aws_s3_bucket_versioning" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}



# Server-Side Encryption (SSE) configuration using AES-256
resource "aws_s3_bucket_server_side_encryption_configuration" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Automated Lifecycle Management for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "raw_lifecycle" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    id     = "cleanup_temp"
    status = "Enabled"

    # Targets only files within the 'temp/' directory prefix
    filter {
      prefix = "temp/"
    }

    # Automatically deletes files after 7 days
    expiration {
      days = 7
    }
  }
}