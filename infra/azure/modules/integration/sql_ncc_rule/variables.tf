variable "ncc_id" {
  type        = string
  description = "The Databricks Network Connectivity Config id (from bootstrap/aws/platform)."
}

variable "endpoint_service_name" {
  type        = string
  description = "The AWS VPC Endpoint Service name fronting the SQL gateway NLB (sql_gateway output)."
}

variable "sql_server_fqdn" {
  type        = string
  description = "The Azure SQL FQDN. Databricks connects by this name; the rule routes it privately."
}

variable "databricks_account_id" {
  type        = string
  description = "The Databricks Account id (UUID from the account console)."
}
