# Inputs mirror the dbx_governance wrapper: the domain JSON arrives as jsonencode'd strings
# (Terragrunt reads the files and pre-filters MANAGED catalogs), plus the config values the
# Snowflake plane needs. Nothing here is secret; the storage integration is provisioned by a
# separate creds layer and referenced by name.

variable "environment" {
  description = "Environment name (dev/prod); prefixes Snowflake role and warehouse names."
  type        = string
}

variable "domain" {
  description = "Domain name (sales/supply/marketing)."
  type        = string
}

variable "owner" {
  description = "The domain owner principal — its Snowflake role sees unmasked values / all rows."
  type        = string
}

variable "storage_bucket" {
  description = "Bucket/container backing the external stages (used to compute stage URLs)."
  type        = string
  default     = ""
}

variable "storage_integration_name" {
  description = "Pre-existing Snowflake storage integration for external stages (from the creds layer)."
  type        = string
  default     = ""
}

variable "catalogs_json" {
  description = "jsonencode'd list of MANAGED catalog objects (with schemas/volumes)."
  type        = string
  default     = "[]"
}

variable "external_locations_json" {
  description = "jsonencode'd list of external location objects ({ location_name, path })."
  type        = string
  default     = "[]"
}

variable "catalog_grants_json" {
  description = "jsonencode'd catalog_grants section."
  type        = string
  default     = "[]"
}

variable "managed_schema_grants_json" {
  description = "jsonencode'd schema_grants section (managed catalogs only)."
  type        = string
  default     = "[]"
}

variable "volume_grants_json" {
  description = "jsonencode'd volume_grants section."
  type        = string
  default     = "[]"
}

variable "ext_loc_grants_json" {
  description = "jsonencode'd external_location_grants section."
  type        = string
  default     = "[]"
}

variable "credit_quota" {
  description = "Monthly credit quota for the domain warehouse's resource monitor."
  type        = number
  default     = 100
}

variable "warehouse_size" {
  description = "Domain warehouse size."
  type        = string
  default     = "XSMALL"
}
