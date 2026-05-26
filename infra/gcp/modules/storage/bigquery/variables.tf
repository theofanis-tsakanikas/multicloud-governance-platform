variable "project_id" {
  description = "The ID of the Google Cloud Project (e.g., databricks-multicloud-platform)"
  type        = string
}

variable "location" {
  description = "The regional location of the BigQuery datasets (e.g., EU or US)"
  type        = string
  default     = "EU"
}

variable "datasets" {
  description = "A list of dataset IDs to be created in BigQuery"
  type        = list(string)
  default     = ["marketing_analytics", "web_analytics"]
}

