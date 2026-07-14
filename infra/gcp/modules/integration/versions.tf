terraform {
  required_providers {
    aws    = { source = "hashicorp/aws" }
    google = { source = "hashicorp/google", version = "~> 7.0" }
    time   = { source = "hashicorp/time", version = "~> 0.13" }
    databricks = {
      source                = "databricks/databricks"
      configuration_aliases = [databricks.account]
    }
  }
}
