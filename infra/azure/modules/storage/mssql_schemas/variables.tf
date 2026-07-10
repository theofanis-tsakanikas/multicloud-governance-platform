variable "sql_database_name" {
  description = "The name of the existing SQL database"
  type        = string
}

variable "mssql_schemas" {
  description = "List of database schemas to create"
  type        = list(string)
}
# Consumed by the provider block Terragrunt generates, not by any resource here.
# Terraform still requires the declaration.
variable "sql_server_fqdn" {
  description = "FQDN of the SQL server the provider connects to."
  type        = string
}

variable "sql_admin_user" {
  description = "SQL admin login."
  type        = string
}

variable "sql_admin_password" {
  description = "SQL admin password, passed through from the mssql layer's state."
  type        = string
  sensitive   = true
}
