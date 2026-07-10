variable "managed_warehouse_name" {
  description = "Display name of the SQL warehouse."
  type        = string
}

variable "managed_cluster_size" {
  description = "Warehouse size (e.g. 2X-Small)."
  type        = string
}

variable "managed_max_num_clusters" {
  description = "Upper bound on autoscaling."
  type        = number
}

variable "managed_auto_stop_mins" {
  description = "Idle minutes before the warehouse suspends."
  type        = number
}

variable "managed_serverless_compute" {
  description = "Whether the warehouse runs on serverless compute."
  type        = bool
}
