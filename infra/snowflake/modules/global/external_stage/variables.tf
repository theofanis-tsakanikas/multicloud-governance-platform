variable "database" {
  description = "The managed database that hosts the external-stage governance schema."
  type        = string
}

variable "external_schema_name" {
  description = "Name of the governance schema that holds external stages."
  type        = string
  default     = "_EXTERNAL"
}

variable "storage_integration_name" {
  description = "Pre-existing Snowflake storage integration (provisioned by the creds/bootstrap layer)."
  type        = string
  default     = ""
}

variable "external_stages" {
  description = "External locations to expose as stages: objects of { name, url }."
  type        = any
  default     = []
}

variable "internal_stages" {
  description = "Volumes to expose as internal stages: objects of { key, name, database, schema }."
  type        = any
  default     = []
}
