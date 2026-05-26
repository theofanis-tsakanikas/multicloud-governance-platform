#########################################
# 1. Global & Environment Configuration
#########################################
variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod, staging)"
  type        = string
}

#########################################
# 2. Connectivity Switch (The Master Key)
#########################################
variable "is_private_connection" {
  description = "If true, deploys RDS in private subnets with VPC Endpoints and ECS Gateway. If false, deploys with Public IP."
  type        = bool
}

#########################################
# 3. Network Configuration
#########################################
variable "rds_vpc_cidr" {
  description = "CIDR block for the dedicated RDS VPC"
  type        = string
}

variable "rds_subnets_config" {
  description = "Map of subnet names to CIDR blocks"
  type        = map(string)
}

#########################################
# 4. Access Control (Public Mode only)
#########################################
variable "orch_ip" {
  description = "List of CIDR blocks (e.g. Orchestrator IP) allowed to access RDS in public mode"
  type        = list(string)
}
