variable "region" { type = string }
variable "environment" { type = string }
variable "is_private_connection" {
  type    = bool
  default = false
}
variable "rds_vpc_cidr" { type = string }
variable "rds_subnets_config" { type = map(string) }
variable "orch_ip" {
  type    = list(string)
  default = []
}
