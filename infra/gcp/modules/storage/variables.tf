variable "project_id" {
  description = "GCP project."
  type        = string
}

variable "location" {
  description = "BigQuery location (multi-region, e.g. EU)."
  type        = string
}

variable "datasets" {
  description = "Dataset names to create — the schemas the federated catalog declares."
  type        = list(string)
}

variable "provider_key" {
  description = "Seed service-account key, consumed by the generated provider block."
  type        = string
  sensitive   = true
  default     = null
}
