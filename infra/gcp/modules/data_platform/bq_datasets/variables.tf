variable "project_id" { type = string }
variable "location" { type = string }
variable "datasets" {
  type        = list(string)
  description = "BigQuery dataset ids to create (the federated catalog's schema names)."
}
variable "provider_key" {
  type        = string
  sensitive   = true
  description = "GCP service-account key JSON for the google provider (from the seed)."
}
