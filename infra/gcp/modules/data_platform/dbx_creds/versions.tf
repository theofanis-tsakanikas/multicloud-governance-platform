terraform {
  required_providers {
    time = { source = "hashicorp/time", version = "~> 0.13" }
    databricks = {
      source = "databricks/databricks", version = "~> 1.0"
    }
  }
}
