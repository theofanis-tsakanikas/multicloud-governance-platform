# --- Databricks Connection ---
variable "gcp_databricks_host" {
  description = "The Databricks Account Console URL (https://accounts.cloud.databricks.com)."
  type        = string
}

variable "gcp_dbx_account_id" {
  description = "The Databricks Account ID (the UUID from the Account Console)."
  type        = string
}

variable "gcp_spn_client_id" {
  description = "The Client ID for the Databricks Service Principal."
  type        = string
  sensitive   = true
}

variable "gcp_spn_client_secret" {
  description = "The Client Secret for the Databricks Service Principal."
  type        = string
  sensitive   = true
}

variable "provider_key" {
  description = "GCP service-account key JSON used by the generated google provider block."
  type        = string
  sensitive   = true
}

# --- AWS & Workspace Config ---
variable "region" {
  description = "The AWS region for deployment."
  type        = string
}

variable "dbx_aws_account_id" {
  description = "The static AWS Account ID of Databricks (414351767826)."
  type        = string
}

variable "managed_workspace_name" {
  description = "The desired name for the Databricks Workspace."
  type        = string
}

# --- Network Inputs (Usually passed from the Network Module) ---
variable "vpc_id" {
  description = "The ID of the VPC created in the previous layer."
  type        = string
}

variable "private_subnet_ids" {
  description = "The list of private subnet IDs for Databricks injection."
  type        = list(string)
}

variable "security_group_id" {
  description = "The ID of the Security Group for the Databricks clusters."
  type        = string
}

# --- Governance ---
variable "metastore_id" {
  description = "The ID of the existing Unity Catalog Metastore."
  type        = string
}

variable "is_private_connection" {
  type        = bool
  description = "Controls whether cross-cloud connectivity uses the private backbone (dedicated workspace + NCC) or the public internet. Set to 'true' to deploy the private workspace."
}