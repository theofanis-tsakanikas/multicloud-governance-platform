variable "environment" {
  description = "The environment name (e.g. dev, prod)"
  type        = string
}

variable "warehouse_prefix" {
  description = "Prefix for the SQL Warehouse name"
  type        = string
}

variable "warehouse_size" {
  description = "Size of the SQL warehouse (2X-Small, X-Small, Small, etc.)"
  type        = string
}

variable "max_num_clusters" {
  description = "Maximum number of clusters for scaling"
  type        = number
}

variable "auto_stop_mins" {
  description = "Minutes of inactivity before stopping the warehouse"
  type        = number
}

variable "warehouse_access_groups" {
  description = "List with the name of the groups that will have access to the sql warehouse"
  type        = list(string)
}

variable "warehouse_permission_level" {
  description = "The permission level for the group (CAN_USE, CAN_MANAGE, etc.)"
  type        = string
}

variable "metastore_id" {
  description = "The ID of the pre-existing Metastore from the Foundation module"
  type        = string
}

variable "admin_group_name" {
  description = "The display name of the admin group (e.g., 'metastore_admins') used for Unity Catalog grants."
  type        = string
}

variable "spn_client_id" {
  description = "Databricks automation SP client id (workspace OAuth)."
  type        = string
}

variable "spn_client_secret" {
  description = "Databricks automation SP client secret (workspace OAuth)."
  type        = string
  sensitive   = true
}
