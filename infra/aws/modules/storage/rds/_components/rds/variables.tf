# --- INPUTS FROM NETWORK MODULE ---
variable "rds_security_group_id" {
  description = "The ID of the Security Group for RDS and Proxy"
  type        = string
}

variable "db_subnet_group_name" {
  description = "The name of the DB Subnet Group"
  type        = string
}

# --- RDS CONFIGURATION ---
variable "db_instance_identifier" {
  description = "The unique identifier for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "The name of the initial database"
  type        = string
}

variable "db_engine" {
  description = "Database engine (e.g., postgres)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "The version of the database engine"
  type        = string
}

variable "db_instance_class" {
  description = "The instance type (e.g., db.t3.micro)"
  type        = string
}

variable "allocated_storage" {
  description = "Storage size in GB"
  type        = number
}

variable "rds_username" {
  description = "Master username for the database"
  type        = string
}

variable "password" {
  description = "The master password (passed from Security layer)"
  type        = string
  sensitive   = true
}

# --- Logic Flags ---
variable "is_private_connection" {
  description = "Boolean flag to determine networking mode"
  type        = bool
}