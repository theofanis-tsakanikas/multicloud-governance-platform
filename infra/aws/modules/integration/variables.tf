variable "environment" { type = string }
variable "region" { type = string }
variable "is_private_connection" {
  type    = bool
  default = false
}
variable "databricks_host" { type = string }
variable "dbx_account_id" { type = string }
variable "spn_client_id" {
  type      = string
  sensitive = true
}
variable "spn_client_secret" {
  type      = string
  sensitive = true
}
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "ecs_security_group_id" { type = string }
variable "rds_security_group_id" { type = string }
variable "ncc_id" {
  type    = string
  default = null
}
variable "rds_secret_arn" { type = string }
variable "endpoint_service_name" {
  type    = string
  default = ""
}
variable "rds_custom_dns_name" { type = string }
variable "private_dns_zone_name" { type = string }
variable "rds_username" { type = string }
variable "ecr_repo_name" { type = string }
variable "ecs_role_arn" { type = string }
variable "db_instance_identifier" { type = string }
variable "proxy_role_arn" { type = string }
