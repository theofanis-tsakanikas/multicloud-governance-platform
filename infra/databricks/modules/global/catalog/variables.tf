variable "catalog" {
  description = "The catalog configuration object including schemas and volumes"
  type = object({
    catalog_name            = string
    type                    = string # MANAGED or FEDERATED
    container               = optional(string)
    path                    = optional(string) # The relative path in S3
    storage_root            = optional(string) # The full S3 URI or External Location name
    connection_name         = optional(string) # Required for FEDERATED catalogs
    database_name           = optional(string)
    calculated_storage_root = optional(string)
    schemas = list(object({
      schema_name = string
      shared      = optional(bool, false)
      volumes = optional(list(object({
        volume_name                 = string
        volume_type                 = string
        container                   = optional(string)
        location_path               = optional(string)
        volume_path                 = optional(string)
        calculated_storage_location = optional(string)
        shared                      = optional(bool, false)
      })), [])
    }))
  })
}

variable "catalog_grants" {
  description = "List of grants filtered for this specific catalog"
  type        = any
  default     = []
}

variable "managed_schema_grants" {
  description = "The global list of schema grants; filtered internally by the module"
  type        = any
  default     = []
}

variable "volume_grants" {
  description = "The global list of volume grants; filtered internally by the module"
  type        = any
  default     = []
}

variable "managed_storage_root" {
  description = "The default S3 bucket path for managed catalogs in this domain"
  type        = string
  default     = null
}