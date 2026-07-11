variable "region" {
  description = "The AWS region where the infrastructure will be deployed."
  type        = string
}

variable "gcp_vpc_cidr" {
  description = "The CIDR block of the GCP for VPN routing purposes."
  type        = list(string)
}

variable "transit_vpc_cidr" {
  description = "GCP's own AWS transit VPC (10.11.0.0/16). It cannot be Azure's 10.10.0.0/16 — that hub is live and carrying Azure SQL."
  type        = string
}

variable "transit_subnets" {
  description = "Private subnets of the GCP transit VPC."
  type        = map(string)
}

variable "transit_nat_cidr" {
  description = "Public subnet for the NAT gateway, inside the transit VPC."
  type        = string
  default     = "10.11.100.0/24"
}

variable "ecr_repo_name" {
  description = "ECR repository for the bq-gateway image."
  type        = string
  default     = "bq-gateway"
}
