variable "environment" {
  description = "The environment name (e.g. dev, prod)"
  type        = string
}

variable "secret_base_path" {
  description = "The base path for the secret naming hierarchy"
  type        = string
}

variable "secret_recovery_window" {
  description = "Days to retain deleted secrets (0 for immediate deletion)"
  type        = number
}

variable "kms_deletion_window" {
  description = "Duration in days after which the key is deleted"
  type        = number
}