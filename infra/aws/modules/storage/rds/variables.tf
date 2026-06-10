variable "environment" {
  type    = string
  default = "dev"
}
variable "region" {
  type    = string
  default = ""
}
variable "db_instance_identifier" { type = string }
variable "db_name" { type = string }
variable "db_engine" { type = string }
variable "engine_version" { type = string }
variable "db_instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "rds_username" { type = string }
variable "password" {
  type      = string
  sensitive = true
}
variable "db_subnet_group_name" { type = string }
variable "rds_security_group_id" { type = string }
variable "is_private_connection" {
  type    = bool
  default = false
}
