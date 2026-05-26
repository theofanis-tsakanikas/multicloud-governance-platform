variable "ncc_id" {
  type        = string
  description = "The ID of the Databricks Network Connectivity Config (NCC) already created in the account"
}

variable "endpoint_service_name" {
  type        = string
  description = "The AWS VPC Endpoint Service Name (e.g., com.amazonaws.vpce.region.vpce-svc-xxx). This is provided by the RDS module output."
}

variable "rds_custom_dns_name" {
  type        = string
  description = "The Custom FQDN (Fully Qualified Domain Name) created in Route 53 that points to the NLB. This exact hostname must be used in Databricks connection strings to trigger the NCC PrivateLink routing."
}

variable "databricks_account_id" {
  type        = string
  description = "The Databricks Account ID (UUID found in the account console)."
}