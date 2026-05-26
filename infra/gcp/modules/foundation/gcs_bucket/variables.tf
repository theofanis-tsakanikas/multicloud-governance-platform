variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "location" {
  description = "The GCS bucket location (Region)"
  type        = string
}

variable "bucket_name" {
  description = "The name of the bucket (must be globally unique)"
  type        = string
}