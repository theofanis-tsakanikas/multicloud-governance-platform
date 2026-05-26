variable "sql_database_name" {
  description = "The name of the existing SQL database"
  type        = string
}

variable "mssql_schemas" {
  description = "List of database schemas to create"
  type        = list(string)
}