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
