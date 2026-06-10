# --- Environment & Naming ---

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "spn_suffix" {
  description = "The suffix used for naming the Service Principal (e.g., automation-sp)."
  type        = string
  default     = "automation-sp"
}

variable "dbx_account_id" {
  description = "The Databricks Account ID (UUID)."
  type        = string
}

# --- AWS Secrets Manager ---

variable "spn_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret where the SPN credentials will be stored."
  type        = string
}

# --- Databricks Identity Management ---

variable "admin_group_name" {
  description = "The display name of the Databricks group that will hold administrative privileges."
  type        = string
}

variable "metastore_admins" {
  description = "A list of User IDs (emails) or Service Principal Application IDs to be added as members of the Admin Group."
  type        = list(string)
}

variable "identity_groups" {
  description = "A list of functional group names to be created within the Databricks Account (e.g., data-engineers, analysts)."
  type        = list(string)
}