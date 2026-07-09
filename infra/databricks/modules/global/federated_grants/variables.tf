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


# Consumed only by the warm-up step (warm_foreign_catalog.py): Unity Catalog does
# not expose a foreign catalog's schemas until a warehouse has queried it.
variable "workspace_host" {
  description = "Workspace URL used to run the SHOW SCHEMAS warm-up query"
  type        = string
}

variable "warehouse_id" {
  description = "SQL warehouse that runs the warm-up query (auto-starts, then auto-suspends)"
  type        = string
}

variable "spn_client_id" {
  description = "Service principal client id used by the warm-up query"
  type        = string
  sensitive   = true
}

variable "spn_client_secret" {
  description = "Service principal client secret used by the warm-up query"
  type        = string
  sensitive   = true
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