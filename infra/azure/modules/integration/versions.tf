terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
    aws     = { source = "hashicorp/aws" }
    random  = { source = "hashicorp/random" }
    time    = { source = "hashicorp/time" }
    databricks = {
      source                = "databricks/databricks"
      configuration_aliases = [databricks.account]
    }
  }
}
