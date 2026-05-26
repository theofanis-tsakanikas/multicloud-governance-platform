variable "rds_schemas" {
  description = "List of PostgreSQL schemas to create for federation"
  type        = list(string)
}