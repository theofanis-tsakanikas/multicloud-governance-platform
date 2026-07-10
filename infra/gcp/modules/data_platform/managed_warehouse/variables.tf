# --- Connection Details (Needed for the Provider) ---

variable "gcp_managed_workspace_host" {
  description = "The URL of the created Databricks workspace (from Deployment output)"
  type        = string
}

variable "gcp_dbx_account_id" {
  description = "The Databricks Account ID"
  type        = string
}

# --- Authentication ---

variable "gcp_spn_client_id" {
  description = "The Client ID of the Service Principal"
  type        = string
}

variable "gcp_spn_client_secret" {
  description = "The Client Secret of the Service Principal"
  type        = string
  sensitive   = true
}


# --- SQL Warehouse Configuration ---
variable "managed_warehouse_name" {
  description = "The name of the SQL Warehouse"
  type        = string
}

variable "managed_cluster_size" {
  description = "Size of the clusters for the SQL Warehouse (e.g., 2X-Small, Small, etc.)"
  type        = string
}

variable "managed_max_num_clusters" {
  description = "Maximum number of clusters for the SQL Warehouse"
  type        = number
}

variable "managed_auto_stop_mins" {
  description = "Time in minutes before the SQL Warehouse automatically stops"
  type        = number
}

variable "managed_serverless_compute" {
  description = "Whether to enable serverless compute for the SQL Warehouse"
  type        = bool
}
variable "is_private_connection" {
  description = "Public mode uses the bootstrap serverless warehouse; this layer creates nothing."
  type        = bool
  default     = false
}
