variable "delta_shares_map_json" {
  type        = string
  description = "A JSON-encoded map of catalogs and their share configurations. Used to dynamically create mounted catalogs in AWS."
}

variable "gcp_metastore_id" {
  type        = string
  description = "The Metastore ID of the GCP environment, used as the provider prefix in the share_name."
}

variable "gcp_provider_name" {
  type        = string
  description = "The Delta Sharing Organization Name of the GCP Metastore, as it appears in the AWS Providers list."
}