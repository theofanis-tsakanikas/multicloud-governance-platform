variable "api_integration_name" {
  description = "Name of the API integration that authorises Snowflake to call the Git origin."
  type        = string
}

variable "allowed_prefix" {
  description = "HTTPS prefix the integration may call, e.g. https://github.com/<org>. Deliberately narrower than 'all of GitHub'."
  type        = string

  validation {
    condition     = startswith(var.allowed_prefix, "https://")
    error_message = "allowed_prefix must be an https:// URL — Snowflake will not call plain http."
  }
}

variable "repo_origin" {
  description = "Clone URL of the repository, e.g. https://github.com/<org>/<repo>. Must sit under allowed_prefix."
  type        = string
}

variable "repository_name" {
  description = "Name of the GIT REPOSITORY object inside Snowflake."
  type        = string
}

variable "database" {
  description = "Database that hosts the repository object."
  type        = string
}

variable "schema" {
  description = "Schema that hosts the repository object — the domain's _GOVERNANCE schema, so it sits with the policies rather than in the data."
  type        = string
}

variable "reader_roles" {
  description = "Functional roles granted READ on the repository. They may read the notebooks; they may not push."
  type        = list(string)
  default     = []
}

variable "git_credentials" {
  description = <<-EOT
    Fully-qualified name of a Snowflake secret holding a GitHub PAT.

    Leave null for a PUBLIC repository — that is the intended shape here, and it is why this
    module has no secret of its own to leak. If the repository must stay private, create a
    snowflake_secret_with_basic_authentication from a fine-grained, read-only, repo-scoped PAT
    (sourced from AWS Secrets Manager like every other credential in this platform — never
    committed, never passed as a plain variable) and pass its fully_qualified_name here.
  EOT
  type        = string
  default     = null
}
