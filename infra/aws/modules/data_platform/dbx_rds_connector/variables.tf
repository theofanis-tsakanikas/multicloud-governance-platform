# --- Databricks Provider Variables ---
variable "serverless_workspace_host" {
  type        = string
  description = "The URL of the Databricks workspace (e.g., https://adb-xxx.x.azuredatabricks.net)"
}

variable "dbx_account_id" {
  type        = string
  description = "The Databricks Account ID"
}

variable "spn_client_id" {
  type        = string
  description = "The Client ID of the Service Principal"
}

variable "spn_client_secret" {
  type        = string
  description = "The Client Secret of the Service Principal"
  sensitive   = true
}

# --- RDS Connection Variables ---
variable "rds_hostname" {
  type        = string
  description = "The Custom FQDN (Fully Qualified Domain Name) created in Route 53 that points to the NLB. This exact hostname must be used in Databricks connection strings to trigger the NCC PrivateLink routing."
}

variable "rds_port" {
  type        = number
  description = "The port for the RDS connection (default: 5432)"
  default     = 5432
}

variable "rds_username" {
  type        = string
  description = "The username for the database connection"
}

variable "password" {
  type        = string
  description = "The password for the database connection"
  sensitive   = true
}

# --- Connection Identity ---
variable "rds_connection_name" {
  type        = string
  description = "The name of the external connection in Databricks Unity Catalog"
  default     = "rds_postgres_connection"
}
/*
variable "rds_proxy_endpoint" {
  type        = string
  description = "The DNS endpoint of the RDS Proxy. Used as the 'host' for Databricks SQL connections."
}
*/
