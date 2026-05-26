variable "environment" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "ecr_repo_name" {
  type    = string
  default = "pgbouncer-gateway"
}

variable "is_private_connection" {
  type    = bool
  default = false
}
