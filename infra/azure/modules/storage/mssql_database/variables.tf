variable "resource_group_name" {
  type        = string
  description = "The name of the existing Resource Group."
}

variable "location" {
  type        = string
  description = "The Azure region where the Resource Group is located."
}

variable "region" {
  description = "The AWS region where resources will be deployed."
  type        = string
}

variable "sql_server_name" {
  type        = string
  description = "The name of the SQL Server. Must be globally unique across Azure."
}

variable "sql_database_name" {
  type        = string
  description = "The name of the MS SQL Database."
}

variable "sql_admin_user" {
  type        = string
  description = "The administrator username for the SQL Server."
}

variable "key_vault_id" {
  type        = string
  description = "The ID of the Key Vault where the SQL password will be stored."
}

variable "sql_password_name" {
  type        = string
  description = "The name of the secret to be created in Key Vault (e.g., sql-admin-password)."
  default     = "sql-admin-password"
}

variable "databricks_aws_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks (e.g., 3.121.230.128/26) corresponding to Databricks Serverless Egress IPs for the specific AWS Region."

  validation {
    condition     = can([for s in var.databricks_aws_cidrs : cidrnetmask(s)])
    error_message = "All elements in the list must be valid CIDR blocks (e.g., x.x.x.x/y)."
  }
}

variable "orch_ip" {
  type        = list(string)
  description = "The public IP of the machine running the orchestrator"
}

variable "is_private_connection" {
  type        = bool
  description = "Controls whether the connection to the Azure SQL Server uses a Private Endpoint (NCC) or the public internet. Set to 'true' to route traffic through the private backbone."
}