variable "federated_catalog" {
  description = "The specific federated catalog object from the JSON"
  type = object({
    catalog_name    = string
    database_name   = optional(string)
    connection_name = string
    type            = string
    schemas = list(object({
      schema_name = string
    }))
  })
}


variable "federated_schema_grants" {
  description = "The complete list of schema grants from the grants JSON"
  type = list(object({
    schema = string
    grants = list(object({
      principal  = string
      privileges = list(string)
    }))
  }))
}