variable "rds_schemas" {
  description = "List of PostgreSQL schemas to create for federation"
  type        = list(string)
}
variable "password" {
  description = "Postgres password for the schema-creation provider (from the RDS secret)."
  type        = string
  sensitive   = true
}
