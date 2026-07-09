variable "catalogs" {
  description = "MANAGED catalog objects from the domain infra JSON (filtered upstream). Each carries catalog_name and optionally owner."
  type        = any
  default     = []
}
