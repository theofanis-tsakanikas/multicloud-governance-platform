variable "location_name" {
  description = "The name of the external location in Unity Catalog"
  type        = string
}

variable "calculated_url" {
  description = "The full cloud URI (s3://... or abfss://...)"
  type        = string
}

variable "storage_credential_name" {
  description = "The name of the storage credential to use"
  type        = string
}

# Governance / Access Control List
variable "external_location_grants" {
  description = "List of location grants from JSON"
  type = list(object({
    location_name = string
    grants = list(object({
      principal  = string
      privileges = list(string)
    }))
  }))
  default = []
}
