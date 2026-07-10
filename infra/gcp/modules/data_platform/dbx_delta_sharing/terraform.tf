terraform {
  required_providers {
    time = { source = "hashicorp/time" }
    databricks = {
      source  = "databricks/databricks"
      version = "1.99.0"
    }
  }
}