variable "rds_schemas" {
  description = "List of PostgreSQL schemas to create for federation"
  type        = list(string)
}
variable "password" {
  description = "Postgres password for the schema-creation provider (from the RDS secret)."
  type        = string
  sensitive   = true
}

variable "drop_cascade" {
  description = "DROP SCHEMA ... CASCADE on destroy, taking the application's tables with it. dev only."
  type        = bool
  default     = false
}

variable "is_private_connection" {
  description = "In private mode the instance has no public address and admits only the gateway's security group, so Terraform cannot reach it from CI at all. The schemas are created by a one-shot ECS task instead — see the comment in main.tf."
  type        = bool
  default     = false
}
