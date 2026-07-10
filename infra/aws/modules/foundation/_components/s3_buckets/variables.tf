variable "environment" {
  type        = string
  description = "Deployment environment (dev, stage, prod)"
}

variable "bucket_name" {
  type        = string
  description = "The name of the bucket"
}



variable "force_destroy" {
  description = "Delete objects and versions when the bucket is destroyed. dev only."
  type        = bool
  default     = false
}
