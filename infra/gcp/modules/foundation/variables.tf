variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "location" {
  description = "Region/location for the bucket."
  type        = string
}

variable "bucket_prefix_name" {
  description = "Prefix of the GCS bucket; the project id is appended for global uniqueness."
  type        = string
}

variable "service_list" {
  description = "GCP APIs to enable before anything else is created."
  type        = list(string)
}

variable "provider_key" {
  description = "Seed service-account key, consumed by the generated provider block."
  type        = string
  sensitive   = true
  default     = null
}
