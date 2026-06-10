# --- Databricks Account Details ---
variable "dbx_account_id" {
  description = "The Databricks Account ID (UUID) found in the Account Console"
  type        = string
}

# --- Workspace Configuration ---
variable "workspace_name" {
  description = "The base name of the workspace (e.g. data-platform)"
  type        = string
}

variable "environment" {
  description = "The environment suffix (e.g. dev, prod)"
  type        = string
}

variable "region" {
  description = "The AWS region where the workspace will be deployed (e.g. eu-central-1)"
  type        = string
}

variable "workspace_pricing_tier" {
  description = "The pricing tier of the workspace. Default is ENTERPRISE for Unity Catalog/Serverless support"
  type        = string
}


variable "cross_account_role_arn" {
  description = "The ARN of the cross account role used for the dbx workspace"
  type        = string
}

variable "metastore_bucket_name" {
  description = "The name of the metastore bucket"
  type        = string
}

# --- Unity Catalog / Metastore Variables ---

variable "metastore_id" {
  description = "The ID of the pre-existing Metastore from the Foundation module"
  type        = string
}

# --- Identity & Permissions Variables ---

variable "admin_group_id" {
  description = "The Databricks Group ID (Principal ID) for workspace admins"
  type        = string
}

variable "functional_group_ids" {
  description = "A map or set of Databricks Group IDs to be assigned as USERs"
  type        = map(string)
  # Example: { "data-scientists" = "12345", "analysts" = "67890" }
}