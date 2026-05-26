variable "project_id" {
  type        = string
  description = "The GCP Project ID where services will be enabled"
}

variable "service_list" {
  type        = list(string)
  description = "List of GCP APIs to enable (e.g., secretmanager.googleapis.com)"
}