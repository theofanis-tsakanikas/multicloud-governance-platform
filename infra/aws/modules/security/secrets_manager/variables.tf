variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "password_name" {
  description = "The base name for the secret in Secrets Manager"
  type        = string
}

variable "rds_username" {
  description = "The master username for the database"
  type        = string
}

variable "db_engine" {
  description = "The database engine (e.g., postgres, mysql)"
  type        = string
}

variable "rds_port" {
  description = "The port on which the DB accepts connections"
  type        = number
}

variable "db_instance_identifier" {
  description = "The unique identifier for the RDS instance"
  type        = string
}