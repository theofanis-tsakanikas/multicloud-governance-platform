variable "ncc_id" {
  description = "The Databricks Network Connectivity Config id (from bootstrap/aws/platform) — the same NCC the RDS and Azure SQL rules bind to."
  type        = string
}
variable "endpoint_service_name" {
  description = "The AWS VPC Endpoint Service name fronting the BigQuery gateway NLB."
  type        = string
}
variable "domain_names" {
  description = "The Google API hosts to route privately. All three are required; see main.tf."
  type        = list(string)
}
