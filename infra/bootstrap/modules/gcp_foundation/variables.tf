variable "project_id" {
  description = "The Google Cloud Project ID where resources will be deployed"
  type        = string
}

variable "location" {
  description = "The GCP region for the resources (e.g., europe-west3)"
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "metastore_bucket_name" {
  description = "The name prefix for the GCS bucket used by Unity Catalog"
  type        = string
}

variable "dbx_system_sa" {
  description = "The Databricks managed Google Service Account email (obtained from the Databricks Account Console)"
  type        = string
}

variable "terraform_sa_account" {
  type        = string
  description = "The email of the Service Account used by Terraform/Orchestrator"
}

variable "dbx_sa_name" {
  type = string
}