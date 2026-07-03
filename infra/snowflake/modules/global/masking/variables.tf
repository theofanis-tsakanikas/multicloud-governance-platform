variable "database" {
  description = "The managed database that hosts the governance schema and its policies."
  type        = string
}

variable "domain" {
  description = "Domain name (used to name the row-access policy)."
  type        = string
}

variable "governance_schema_name" {
  description = "Name of the governance schema holding policies and the classification tag."
  type        = string
  default     = "_GOVERNANCE"
}

variable "masked_classifications" {
  description = "Classifications that receive a masking policy."
  type        = list(string)
  default     = ["confidential", "pii"]
}

variable "classified_schemas" {
  description = "Schemas to tag: objects of { schema = \"db.schema\", classification }."
  type        = any
  default     = []
}

variable "privileged_role" {
  description = "The Snowflake role that sees unmasked values / all rows (e.g. the domain owner role)."
  type        = string
}
