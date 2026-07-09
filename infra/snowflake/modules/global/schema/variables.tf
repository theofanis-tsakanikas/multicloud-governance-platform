variable "schemas" {
  description = "Flattened schema list: objects of { database, schema_name, classification }."
  type        = any
  default     = []
}
