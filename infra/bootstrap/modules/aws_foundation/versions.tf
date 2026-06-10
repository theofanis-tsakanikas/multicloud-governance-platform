terraform {
  required_providers {
    aws        = { source = "hashicorp/aws", version = "6.25.0" }
    databricks = { source = "databricks/databricks", version = "1.99.0" }
    time       = { source = "hashicorp/time", version = "0.13.1" }
  }
}
