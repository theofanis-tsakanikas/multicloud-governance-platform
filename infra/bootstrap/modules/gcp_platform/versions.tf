terraform {
  required_providers {
    databricks = { source = "databricks/databricks", version = "1.99.0" }
    google     = { source = "hashicorp/google", version = "~> 5.0" }
    time       = { source = "hashicorp/time", version = "0.13.1" }
  }
}
