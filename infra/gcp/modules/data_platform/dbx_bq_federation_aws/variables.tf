variable "connection_name" {
  description = "UC connection name (bq_conn), from the domain contract."
  type        = string
}

variable "catalog_name" {
  description = "FEDERATED catalog name (marketing_bq_fed). Same name as the GCP workspace's, in a different metastore — deliberately."
  type        = string
}

variable "project_id" {
  description = "GCP project holding the BigQuery datasets."
  type        = string
}

variable "bq_key" {
  description = "Google service-account key JSON for the federation SA. Never committed; created by the gcp/security layer and passed through state."
  type        = string
  sensitive   = true
}

variable "reader_groups" {
  description = "Groups granted read on the federated catalog."
  type        = list(string)
  default     = ["data_engineers"]
}

variable "spn_client_id" {
  description = "AWS Databricks SPN — consumed by the generated provider block."
  type        = string
  default     = ""
}

variable "spn_client_secret" {
  type      = string
  default   = ""
  sensitive = true
}
