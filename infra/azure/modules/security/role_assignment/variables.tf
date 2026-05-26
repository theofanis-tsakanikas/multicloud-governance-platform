variable "adls_account_id" {
  description = "The ID of the ADLS Storage Account (from adls_account module)."
  type        = string
}

variable "spn_object_id" {
  description = "The Object ID of the Service Principal (from service_principal module)."
  type        = string
}

variable "role_names" {
  description = "List of roles to assign to the Service Principal"
  type        = list(string)
}