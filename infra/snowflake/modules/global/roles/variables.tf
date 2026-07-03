variable "role_prefix" {
  description = "Prefix applied to every functional role name (e.g. the environment: DEV / PROD)."
  type        = string
}

variable "principals" {
  description = "The governance principals (group names) that appear in the domain grants."
  type        = list(string)
}
